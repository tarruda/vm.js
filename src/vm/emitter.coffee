{parse} = esprima
Script = require './script'
opcodes = require './opcodes'
Visitor = require '../ast/visitor'
{hasProp} = require '../runtime/util'
    
# Last visitor applied in the compilation pipeline, it
# emits opcodes to be executed in the vm
class Emitter extends Visitor
  constructor: (scopes, @filename, @name, @original, @source) ->
    @instructions = []
    @labels = []
    @scripts = []
    @tryStatements = []
    @withLevel = 0
    # Stack of scopes. Each scope maintains a name -> index association
    # where index is unique per script(function or code executing in global
    # scope)
    @scopes = scopes or []
    if scopes
      @scriptScope = scopes[0]
    @localNames = []
    @varIndex = 2
    @guards = []
    @currentLine = -1
    @currentColumn = -1
    @stringIds = {}
    @strings = []
    @regexpIds = {}
    @regexps = []
    @ignoreNotDefined = 0

  scope: (name) ->
    i = 0
    crossFunctionScope = false
    for scope in @scopes
      if hasProp(scope, name)
        return [i, scope[name]]
      # only scopes after the function scope will increase the index
      if crossFunctionScope or scope == @scriptScope
        crossFunctionScope = true
        i++
    return null

  scopeGet: (name) ->
    if @withLevel
      @GETW(name, @ignoreNotDefined)
      @ignoreNotDefined = 0
      return
    scope = @scope(name)
    if scope
      @ignoreNotDefined = 0
      @GETL.apply(this, scope)
      return
    @GETG(name, @ignoreNotDefined) # global object get
    @ignoreNotDefined = 0
    return

  scopeSet: (name) ->
    if @withLevel
      return @SETW(name)
    scope = @scope(name)
    if scope
      return @SETL.apply(this, scope)
    @SETG(name) # global object set

  enterScope: ->
    if not @scopes.length
      # only enter a nested scope when running global code as local variables
      # are identified by an integer and not name
      @ENTER_SCOPE()
    @scopes.unshift({})

  exitScope: ->
    @scopes.shift()
    if not @scopes.length
      # back to global scope
      @EXIT_SCOPE()

  addCleanupHook: (cleanup) ->
    # add cleanup instructions to all named labels
    for label in @labels
      if label.name
        if not label.cleanup
          label.cleanup = []
        label.cleanup.push(cleanup)
    # also add to all enclosing try/catch/finally blocks that may exit
    # the block
    for tryStatement in @tryStatements
      tryStatement.hooks.push(cleanup)

  declareVar: (name, kind) ->
    if kind in ['const', 'var']
      scope = @scriptScope
    else
      scope = @scopes[0]
    if scope and not scope[name]
      @localNames[@varIndex] = name
      scope[name] = @varIndex++
    # else this is a global variable

  declarePattern: (node, kind) ->
    if node.type in ['ArrayPattern', 'ArrayExpression']
      for el in node.elements
        if el
          @declarePattern(el, kind)
    else if node.type in ['ObjectPattern', 'ObjectExpression']
      for prop in node.properties
        @declarePattern(prop.value, kind)
    else if node.type is 'Identifier'
      @declareVar(node.name, kind)
    else
      throw new Error('assertion error')
     
  newLabel: -> new Label(this)

  label: (name) ->
    if not name
      return @labels[@labels.length - 1]
    for label in @labels
      if label.name is name
        return label
    return null

  pushLabel: (name, stmt, brk, cont) ->
    @labels.push({name: name, stmt: stmt, brk: brk, cont: cont})

  popLabel: -> @labels.pop()
    
  declareFunction: (name, index) ->
    @declareVar(name)
    scope = @scope(name)
    if scope
      opcode = new SETL(scope)
    else
      opcode = new SETG([name])
    # a function is declared by binding a name to the function ref
    # before other statements that are not function declarations
    codes = [
      new FUNCTION([index])
      opcode
      new POP()
    ]
    @instructions = codes.concat(@instructions)
    processedLabels = {}
    for i in [0...@instructions.length]
      code = @instructions[i]
      # replace all GETG/GETL instructions that match the declared name on
      # a parent scope by GETL of the matched index in the local scope
      if @scopes.length and code instanceof GETG
        if code.args[0] == name
          @instructions[i] = new GETL(scope)
      if code instanceof GETL
        if code.args[0] != 0
          s = @scopes[code.args[0]]
          if s[name] == code.args[1]
            @instructions[i] = new GETL(scope)
      # update all labels offsets
      code.forEachLabel (l) ->
        if hasProp(processedLabels, l.id)
          # the same label can be reused between instructions, this will
          # ensure we only visit each label once
          return l
        processedLabels[l.id] = null
        if l.ip?
          # only offset marked labels
          l.ip += 3
        return l

  end: ->
    for code in @instructions
      code.forEachLabel (l) ->
        if l.ip is null
          throw new Error('label has not been marked')
        return l.ip
    for guard in @guards
      guard.start = guard.start.ip
      guard.handler = guard.handler.ip if guard.handler
      guard.finalizer = guard.finalizer.ip if guard.finalizer
      guard.end = guard.end.ip
    # calculate the maximum evaluation stack size
    max = 1 # at least 1 stack size is needed for the arguments object
    current = 0
    for code in @instructions
      current += code.calculateFactor()
      max = Math.max(current, max)
    localLength = 0
    for k in @localNames
      localLength++
    # compile all functions
    for i in [0...@scripts.length]
      @scripts[i] = @scripts[i]()
    return new Script(@filename, @name, @instructions, @scripts, @localNames,
      localLength, @guards, max, @strings, @regexps, @source)

  visit: (node) ->
    if not node?
      # eg: the 'alternate' block of an if statement
      return
    if node.loc
      {line, column} = node.loc.start
      if line != @currentLine
        idx = @instructions.length - 1
        while (@instructions[idx] instanceof opcodes.LINE or
        @instructions[idx] instanceof opcodes.COLUMN)
          @instructions.pop()
          idx--
        @LINE(line)
        @currentLine = line
      else if column != @currentColumn
        idx = @instructions.length - 1
        while @instructions[idx] instanceof opcodes.COLUMN
          @instructions.pop()
          idx--
        @COLUMN(column)
        @currentColumn = column
    return super(node)

  BlockStatement: (node) ->
    @enterScope()
    if node.blockInit
      node.blockInit()
    @visit(node.body)
    if node.blockCleanup
      node.blockCleanup()
    @exitScope()
    return node

  VmLoop: (node, emitInit, emitBeforeTest, emitUpdate, emitAfterTest) ->
    blockInit = =>
      if emitInit
        emitInit(brk)
      if emitUpdate
        start.mark()
      else
        cont.mark()
      if emitBeforeTest
        emitBeforeTest()
        @JMPF(brk)

    blockCleanup = =>
      if emitUpdate
        cont.mark()
        emitUpdate(brk)
        @POP()
        @JMP(start)
      if emitAfterTest
        emitAfterTest()
        @JMPF(brk)
      @JMP(cont)

    currentLabel = @label()
    start = @newLabel()
    cont = @newLabel()
    brk = @newLabel()

    if currentLabel?.stmt is node
      # adjust current label 'cont' so 'continue label' will work
      currentLabel.cont = cont
    @pushLabel(null, node, brk, cont)
    if node.body.type == 'BlockStatement'
      node.body.blockInit = blockInit
      node.body.blockCleanup = blockCleanup
      @visit(node.body)
    else
      @enterScope()
      blockInit()
      @visit(node.body)
      blockCleanup()
      @exitScope()
    brk.mark()
    @popLabel()
    return node

  VmIteratorLoop: (node, pushIterator) ->
    labelCleanup = (label, isBreak) =>
      if not label or label.stmt != node or isBreak
        @POP()

    emitInit = (brk) =>
      if node.left.type == 'VariableDeclaration'
        @visit(node.left)
      @visit(node.right)
      pushIterator()
      emitUpdate(brk)
      @POP()

    emitUpdate = (brk) =>
      @DUP()
      @NEXT(brk)
      @visit(assignNext()) # assign next to the iteration variable

    assignNext = -> {
      loc: node.left.loc
      type: 'AssignmentExpression'
      operator: '='
      left: assignTarget
    }

    @addCleanupHook(labelCleanup)
    assignTarget = node.left
    if assignTarget.type == 'VariableDeclaration'
      assignTarget = node.left.declarations[0].id
    @VmLoop(node, emitInit, null, emitUpdate)
    @POP()
    return node

  WhileStatement: (node) ->
    emitBeforeTest = =>
      @visit(node.test)

    @VmLoop(node, null, emitBeforeTest)
    return node

  DoWhileStatement: (node) ->
    emitAfterTest = =>
      @visit(node.test)

    @VmLoop(node, null, null, null, emitAfterTest)
    return node

  ForStatement: (node) ->
    emitInit = =>
      @visit(node.init)
      if node.init.type != 'VariableDeclaration'
        @POP()

    emitBeforeTest = =>
      @visit(node.test)

    emitUpdate = =>
      @visit(node.update)

    @VmLoop(node, emitInit, emitBeforeTest, emitUpdate)
    return node

  ForInStatement: (node) ->
    pushIterator = =>
      @ENUMERATE()

    @VmIteratorLoop(node, pushIterator)
    return node

  ForOfStatement: (node) ->
    pushIterator = =>
      @ITER()

    @VmIteratorLoop(node, pushIterator)
    return node

  ExpressionStatement: (node) ->
    super(node)
    # remove the expression value from the stack and save it
    @SREXP()
    return node

  IfStatement: (node) ->
    ifTrue = @newLabel()
    end = @newLabel()
    @visit(node.test)
    @JMPT(ifTrue)
    @visit(node.alternate)
    @JMP(end)
    ifTrue.mark()
    @visit(node.consequent)
    end.mark()
    return node

  LabeledStatement: (node) ->
    brk = @newLabel()
    @pushLabel(node.label.name, node.body, brk)
    @visit(node.body)
    brk.mark()
    @popLabel()
    return node

  BreakStatement: (node) ->
    if node.label
      label = @label(node.label.name)
      if label.cleanup
        for cleanup in label.cleanup
          cleanup(label, true)
    else
      label = @label()
    @JMP(label.brk)
    return node

  ContinueStatement: (node) ->
    if node.label
      label = @label(node.label.name)
      if label.cleanup
        for cleanup in label.cleanup
          cleanup(label, false)
    else
      label = @label()
    @JMP(label.cont)
    return node

  WithStatement: (node) ->
    @visit(node.object)
    @ENTER_WITH()
    @withLevel++
    @visit(node.body)
    @withLevel--
    @EXIT_SCOPE()
    return node

  SwitchStatement: (node) ->
    brk = @newLabel()
    @pushLabel(null, node, brk)
    @addCleanupHook((=> @POP(); @exitScope()))
    @enterScope()
    @visit(node.discriminant)
    nextBlock = @newLabel()
    for clause in node.cases
      nextTest = @newLabel()
      if clause.test
        @DUP()
        @visit(clause.test)
        @CID()
        @JMPF(nextTest)
        @JMP(nextBlock)
      if clause.consequent.length
        nextBlock.mark()
        @visit(clause.consequent)
        nextBlock = @newLabel()
        @JMP(nextBlock) # fall to the next block
      nextTest.mark()
    nextBlock.mark()
    @popLabel()
    brk.mark()
    @POP()
    @exitScope()
    return node

  ReturnStatement: (node) ->
    # for hook in @returnHooks
    #   hook()
    if node.argument
      @visit(node.argument)
      @RETV()
    else
      @RET()
    return node

  ThrowStatement: (node) ->
    super(node)
    @THROW()
    return node

  TryStatement: (node) ->
    if node.handlers.length > 1
      throw new Error('assert error')
    @tryStatements.push({hooks: []})
    start = @newLabel()
    handler = @newLabel()
    finalizer = @newLabel()
    end = @newLabel()
    guard = {
      start: start
      handler: if node.handlers.length then handler else null
      finalizer: if node.finalizer then finalizer else null
      end: end
    }
    @guards.push(guard)
    start.mark()
    @visit(node.block)
    @JMP(finalizer)
    handler.mark()
    if node.handlers.length
      node.handlers[0].body.blockInit = =>
        # bind error to the declared pattern
        param = node.handlers[0].param
        @declarePattern(param)
        assign = {
          type: 'ExpressionStatement'
          expression: {
            loc: param.loc
            type: 'AssignmentExpression'
            operator: '='
            left: param
          }
        }
        @visit(assign)
        # run cleanup hooks
        for hook in @tryStatements[@tryStatements.length - 1].hooks
          hook()
      @visit(node.handlers[0].body)
    finalizer.mark()
    if node.finalizer
      @visit(node.finalizer)
      if not node.handlers.length
        for hook in @tryStatements[@tryStatements.length - 1].hooks
          hook()
        # return from the function so the next frame can be checked
        # for a guard
        @RET()
    end.mark()
    @tryStatements.pop()
    return node

  DebuggerStatement: (node) ->
    @DEBUG()
    return node

  VariableDeclaration: (node) ->
    for decl in node.declarations
      decl.kind = node.kind
    @visit(node.declarations)
    return node

  VariableDeclarator: (node) ->
    @declarePattern(node.id, node.kind)
    if node.init
      assign = {
        type: 'ExpressionStatement'
        expression: {
          loc: node.loc
          type: 'AssignmentExpression'
          operator: '='
          left: node.id
          right: node.init
        }
      }
      @visit(assign)
    return node

  ThisExpression: (node) ->
    if @scopes.length
      @scopeGet('this')
    else
      @GLOBAL()
    return node

  ArrayExpression: (node) ->
    super(node)
    @ARRAY_LITERAL(node.elements.length)
    return node

  ObjectExpression: (node) ->
    for property in node.properties
      if property.kind is 'init' # object literal
        @visit(property.value)
        if property.key.type is 'Literal'
          @visit(property.key)
        else # identifier. use the name to create a literal string
          @visit({type: 'Literal', value: property.key.name})
      else
        throw new Error("property kind '#{property.kind}' not implemented")
    @OBJECT_LITERAL(node.properties.length)
    return node

  VmFunction: (node) ->
    {
      start: {line: sline, column: scol},
      end: {line: eline, column: ecol}
    } = node.loc
    source = @original.slice(sline - 1, eline)
    source[0] = source[0].slice(scol)
    source[source.length - 1] = source[source.length - 1].slice(0, ecol)
    source = source.join('\n')
    name = '<anonymous>'
    if node.id
      name = node.id.name
    # emit function code only at the end so it can access all scope
    # variables defined after it
    emit = =>
      initialScope = {this: 0, arguments: 1}
      if node.lexicalThis
        delete initialScope.this
      fn = new Emitter([initialScope].concat(@scopes), @filename,
        name, @original, source)
      # load the the 'arguments' object into the local scope
      fn.ARGS()
      len = node.params.length
      if node.rest
        # initialize rest parameter
        fn.declareVar(node.rest.name)
        scope = fn.scope(node.rest.name)
        fn.REST(len, scope[1])
      # initialize parameters
      for i in [0...len]
        param = node.params[i]
        def = node.defaults[i]
        declaration = parse("var placeholder = arguments[#{i}] || 0;").body[0]
        declarator = declaration.declarations[0]
        declarator.id = param
        if def then declarator.init.right = def
        else declarator.init = declarator.init.left
        fn.visit(declaration)
      # emit function body
      if node.body.type == 'BlockStatement'
        fn.visit(node.body.body)
      else
        # arrow expression
        fn.visit(node.body)
        fn.RETV()
      return fn.end()
    functionIndex = @scripts.length
    @scripts.push(emit)
    if node.isExpression
      # push function on the stack
      @FUNCTION(functionIndex)
    if node.declare
      # declare so the function will be bound at the beginning of the context
      @declareFunction(node.declare, functionIndex)
    return node

  FunctionDeclaration: (node) ->
    node.isExpression = false
    node.declare = node.id.name
    @VmFunction(node)
    return node

  FunctionExpression: (node) ->
    node.isExpression = true
    node.declare = false
    @VmFunction(node)
    return node

  ArrowFunctionExpression: (node) ->
    node.isExpression = true
    node.declare = false
    node.lexicalThis = true
    @VmFunction(node)
    return node

  SequenceExpression: (node) ->
    for i in [0...node.expressions.length - 1]
      @visit(node.expressions[i])
      @POP()
    @visit(node.expressions[i])
    return node

  UnaryExpression: (node) ->
    if node.operator == 'delete'
      if node.argument.type == 'MemberExpression'
        @visitProperty(node.argument)
        @visit(node.argument.object)
        @DEL()
      else if node.argument.type == 'Identifier' and not @scopes.length
        # global property
        @LITERAL(node.argument.name)
        @GLOBAL()
        @DEL()
      else
        # no-op
        @LITERAL(false)
    else
      if node.operator == 'typeof' and node.argument.type == 'Identifier'
        @ignoreNotDefined = 1
      super(node)
      @[unaryOp[node.operator]]()
    return node

  BinaryExpression: (node) ->
    super(node)
    @[binaryOp[node.operator]]()
    return node

  LogicalExpression: (node) ->
    evalEnd = @newLabel()
    @visit(node.left)
    @DUP()
    if node.operator is '||'
      @JMPT(evalEnd)
    else
      @JMPF(evalEnd)
    @POP()
    @visit(node.right)
    evalEnd.mark()
    return node

  ConditionalExpression: (node) ->
    @IfStatement(node)
    return node

  NewExpression: (node) ->
    @visit(node.arguments) # push arguments
    @visit(node.callee)
    @NEW(node.arguments.length)
    return node

  CallExpression: (node) ->
    @visit(node.arguments) # push arguments
    if node.callee.type is 'MemberExpression'
      @visit(node.callee.object) # push target
      @SR1() # save target
      @LR1() # load target
      @visitProperty(node.callee) # push property
      if node.callee.property.type == 'Identifier'
        fname = node.callee.property.name
      @CALLM(node.arguments.length, fname)
    else
      @visit(node.callee)
      if node.callee.type == 'Identifier'
        fname = node.callee.name
      @CALL(node.arguments.length, fname)
    return node

  visitProperty: (memberExpression) ->
    if memberExpression.computed
      @visit(memberExpression.property)
    else if memberExpression.property.type is 'Identifier'
      @LITERAL(memberExpression.property.name)
    else if memberExpression.property.type is 'Literal'
      @LITERAL(memberExpression.property.value)
    else
      throw new Error('invalid assert')

  MemberExpression: (node) ->
    @visitProperty(node)
    @visit(node.object)
    @GET()
    return node

  AssignmentExpression: (node) ->
    if node.right
      if node.right.type is 'MemberExpression' and not node.right.object
        # destructuring pattern, need to adjust the stack before
        # getting the value
        @visitProperty(node.right)
        @SWAP()
        @GET()
      else
        @visit(node.right)
    # else, assume value is already on the stack
    if node.left.type in ['ArrayPattern', 'ArrayExpression',
      'ObjectPattern', 'ObjectExpression']
      if node.left.type in ['ArrayPattern', 'ArrayExpression']
        index = 0
        for element in node.left.elements
          if element
            @DUP()
            # get the nth-item from the array
            childAssignment = {
              operator: node.operator
              type: 'AssignmentExpression'
              left: element
              right: {
                type: 'MemberExpression'
                # omit the object since its already loaded on stack
                property: {type: 'Literal', value: index}
              }
            }
            @visit(childAssignment)
            @POP()
          index++
      else
        for property in node.left.properties
          @DUP()
          source = property.key
          target = property.value
          childAssignment = {
            operator: node.operator
            type: 'AssignmentExpression'
            left: target
            right: {
              type: 'MemberExpression'
              computed: true
              property: {type: 'Literal', value: source.name}
            }
          }
          @visit(childAssignment)
          @POP()
      return
    if node.left.type is 'MemberExpression'
      @visitProperty(node.left)
      @visit(node.left.object)
      @SR2()
      @SR1()
      if node.operator != '='
        @LR1()
        @LR2()
        @GET() # get current value
        # swap new/old values
        # @SWAP()
        # apply operator
        @[binaryOp[node.operator.slice(0, node.operator.length - 1)]]()
        @LR1() # load property
        @LR2() # load object
        @SET() # set
      else
        @LR1() # load property
        @LR2() # load object
        @SET()
    else
      if node.operator != '='
        @scopeGet(node.left.name)
        @SWAP()
        # apply operator
        @[binaryOp[node.operator.slice(0, node.operator.length - 1)]]()
      @scopeSet(node.left.name) # set value
    return node

  UpdateExpression: (node) ->
    if node.argument.type is 'MemberExpression'
      @visitProperty(node.argument)
      @visit(node.argument.object)
      @SR2()
      @SR1()
      @LR1()
      @LR2()
      @GET() # get current
      @SR3() # save current
      @LR3() # load current
      if node.operator is '++' then @INC() else @DEC() # apply operator
      @LR1() # load property
      @LR2() # load object
      @SET()
    else
      @scopeGet(node.argument.name)
      @SR3()
      @LR3()
      if node.operator is '++' then @INC() else @DEC()
      @scopeSet(node.argument.name)
    if not node.prefix
      @POP()
      @LR3()
    return node

  Identifier: (node) ->
    # An identifier. Note that an identifier may be an expression or a
    # destructuring pattern.
    @scopeGet(node.name)
    return node

  Literal: (node) ->
    val = node.value
    if typeof val == 'undefined'
      @UNDEF()
    # variable-length literals(strings and regexps) are stored in arrays
    # and referenced by index
    else if typeof val == 'string'
      if not hasProp(@stringIds, val)
        @strings.push(val)
        idx = @strings.length - 1
        @stringIds[val] = idx
      idx = @stringIds[val]
      @STRING_LITERAL(idx)
    else if val instanceof RegExp
      id = Script.regexpToString(val)
      if not hasProp(@regexpIds, id)
        @regexps.push(val)
        idx = @regexps.length - 1
        @regexpIds[id] = idx
      idx = @regexpIds[id]
      @REGEXP_LITERAL(idx)
    else
      @LITERAL(val)
    return node

  YieldExpression: (node) ->
    # A yield expression
    throw new Error('not implemented')

  ComprehensionExpression: (node) ->
    # An array comprehension. The blocks array corresponds to the sequence
    # of for and for each blocks. The optional filter expression corresponds
    # to the final if clause, if present
    throw new Error('not implemented')

  ComprehensionBlock: (node) ->
    # A for or for each block in an array comprehension or generator expression
    throw new Error('not implemented')

  ClassExpression: (node) ->
    throw new Error('not implemented')

  ClassBody: (node) ->
    throw new Error('not implemented')

  ClassDeclaration: (node) ->
    throw new Error('not implemented')

  ClassHeritage: (node) ->
    throw new Error('not implemented')

  ExportBatchSpecifier: (node) ->
    throw new Error('not implemented')

  ExportSpecifier: (node) ->
    throw new Error('not implemented')

  ExportDeclaration: (node) ->
    throw new Error('not implemented')

  ImportSpecifier: (node) ->
    throw new Error('not implemented')

  ImportDeclaration: (node) ->
    throw new Error('not implemented')

  MethodDefinition: (node) ->
    throw new Error('not implemented')

  Property: (node) ->
    throw new Error('not implemented')

  ModuleDeclaration: (node) ->
    throw new Error('not implemented')

  SpreadElement: (node) ->
    throw new Error('not implemented')

  TemplateElement: (node) ->
    throw new Error('not implemented')

  TaggedTemplateExpression: (node) ->
    throw new Error('not implemented')

  TemplateLiteral: (node) ->
    throw new Error('not implemented')


( ->
  # create an Emitter method for each opcode
  for opcode in opcodes
    do (opcode) ->
      opcodes[opcode::name] = opcode
      opcode::forEachLabel = (cb) ->
        if @args
          for i in [0...@args.length]
            if @args[i] instanceof Label
              @args[i] = cb(@args[i])
      # also add a method for resolving label addresses
      Emitter::[opcode::name] = (args...) ->
        if not args.length
          args = null
        @instructions.push(new opcode(args))
        return
)()

class Label
  @id: 1

  constructor: (@emitter) ->
    @id = Label.id++
    @ip = null

  mark: -> @ip = @emitter.instructions.length


{GETL, SETL, GETG, SETG, FUNCTION, POP} =  opcodes

unaryOp = {
  '-': 'INV'
  '!': 'LNOT'
  '~': 'NOT'
  'typeof': 'TYPEOF'
  'void': 'VOID'
}

binaryOp = {
  '==': 'CEQ'
  '!=': 'CNEQ'
  '===': 'CID'
  '!==': 'CNID'
  '<': 'LT'
  '<=': 'LTE'
  '>': 'GT'
  '>=': 'GTE'
  '<<': 'SHL'
  '>>': 'SAR'
  '>>>': 'SHR'
  '+': 'ADD'
  '-': 'SUB'
  '*': 'MUL'
  '/': 'DIV'
  '%': 'MOD'
  '|': 'OR'
  '&': 'AND'
  '^': 'XOR'
  'in': 'IN'
  'instanceof': 'INSTANCEOF'
}


assignOp = {
  '+=': 'ADD'
  '-=': 'SUB'
  '*=': 'MUL'
  '/=': 'DIV'
  '%=': 'MOD'
  '<<=': 'SHL'
  '>>=': 'SAR'
  '>>>=': 'SHR'
  '|=': 'OR'
  '&=': 'AND'
  '^=': 'XOR'
}


module.exports = Emitter
