{parse} = esprima
opcodes = require './opcodes'
Visitor = require '../ast/visitor'
    
# Last visitor applied in the compilation pipeline, it
# emits opcodes to be executed in the vm
class Emitter extends Visitor
  constructor: (scopes) ->
    @instructions = []
    @labels = []
    @scripts = []
    @switches = []
    # Stack of scopes. Each scope maintains a name -> index association
    # where index is unique per script(function or code executing in global
    # scope)
    @scopes = scopes or []
    if scopes
      @scriptScope = scopes[0]
    @localNames = {}
    @varIndex = 1
    @guards = []

  scope: (name) ->
    i = 0
    for scope in @scopes
      if name of scope
        return [i, scope[name]]
      i++
    return null

  scopeGet: (name) ->
    scope = @scope(name)
    if scope
      return @GETL.apply(this, scope)
    @GETG(name) # global object get

  scopeSet: (name) ->
    scope = @scope(name)
    if scope
      return @SETL.apply(this, scope)
    @SETG(name) # global object set

  enterScope: ->
    @ENTER_SCOPE()
    @scopes.unshift({})

  exitScope: ->
    @EXIT_SCOPE()
    @scopes.shift()

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
     
  newLabel: -> new Label(@instructions)

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
      opcode = new opcodes.SETL(scope)
    else
      opcode = new opcodes.SETG([name])
    # a function is declared by binding a name to the function ref
    # before other statements that are not function declarations
    codes = [
      new opcodes.FUNCTION([index])
      opcode
      new opcodes.POP()
    ]
    @instructions = codes.concat(@instructions)

  end: ->
    for code in @instructions
      code.normalizeLabels()
    for guard in @guards
      guard.start = guard.start.ip
      guard.handler = guard.handler.ip if guard.handler
      guard.finalizer = guard.finalizer.ip if guard.finalizer
      guard.end = guard.end.ip
    # calculate the maximum evaluation stack size
    max = 0
    current = 0
    for code in @instructions
      current += code.calculateFactor()
      max = Math.max(current, max)
    localLength = 0
    for k of @localNames
      localLength++

    return new Script(@instructions, @scripts, @localNames, localLength,
      @guards, max)

  BlockStatement: (node) ->
    if node.disableScope
      @visit(node.body)
    else
      @enterScope()
      @visit(node.body)
      @exitScope()

  VmLoop: (node, emitInit, emitBeforeTest, emitUpdate, emitAfterTest) ->
    currentLabel = @label()
    start = @newLabel()
    cont = @newLabel()
    if currentLabel?.stmt is node
      brk = currentLabel.brk
      currentLabel.cont = cont
    else
      pop = true
      brk = @newLabel()
      @pushLabel(null, node, brk, cont)
    if not node.body.disableScope
      node.body.disableScope = true
      @enterScope()
    if emitInit
      emitInit(brk)
    if emitUpdate
      start.mark()
    else
      cont.mark()
    if emitBeforeTest
      emitBeforeTest()
      @JMPF(brk)
    @visit(node.body)
    if emitUpdate
      cont.mark()
      emitUpdate(brk)
      @POP()
      @JMP(start)
    if emitAfterTest
      emitAfterTest()
      @JMPF(brk)
    @JMP(cont)
    if not node.body.disableScope
      @exitScope()
    if pop
      brk.mark()
      @popLabel()

  VmIteratorLoop: (node, pushIterator) ->
    emitInit = (brk) =>
      @visit(node.right)
      pushIterator()
      emitUpdate(brk)
      @POP()

    emitUpdate = (brk) =>
      @DUP()
      @NEXT(brk)
      @visit(assignNext()) # assign next to the iteration variable

    assignNext = ->
      loc: node.left.loc
      type: 'AssignmentExpression'
      operator: '='
      left: assignTarget

    @enterScope()
    node.body.disableScope = true
    assignTarget = node.left
    if assignTarget.type == 'VariableDeclaration'
      assignTarget = node.left.declarations[0].id
      @visit(node.left)

    @VmLoop(node, emitInit, null, emitUpdate)
    @exitScope()
    @POP()

  WhileStatement: (node) ->
    emitBeforeTest = =>
      @visit(node.test)

    @VmLoop(node, null, emitBeforeTest)

  DoWhileStatement: (node) ->
    emitAfterTest = =>
      @visit(node.test)

    @VmLoop(node, null, null, null, emitAfterTest)

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

  ForInStatement: (node) ->
    pushIterator = =>
      @ENUMERATE()

    @VmIteratorLoop(node, pushIterator)

  ForOfStatement: (node) ->
    pushIterator = =>
      @ITER()

    @VmIteratorLoop(node, pushIterator)

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

  LabeledStatement: (node) ->
    brk = @newLabel()
    @pushLabel(node.label.name, node.body, brk)
    @visit(node.body)
    brk.mark()
    @popLabel()

  BreakStatement: (node) ->
    if node.label
      label = @label(node.label.name)
    else
      label = @label()
    @JMP(label.brk)

  ContinueStatement: (node) ->
    if node.label
      label = @label(node.label.name)
    else
      label = @label()
    @JMP(label.cont)

  WithStatement: (node) ->
    throw new Error('not implemented')

  SwitchStatement: (node) ->
    brk = @newLabel()
    @pushLabel(null, node, brk)
    @enterScope()
    @visit(node.discriminant)
    for clause in node.cases
      nextLabel = @newLabel()
      if clause.test
        @DUP()
        @visit(clause.test)
        @CID()
        @JMPF(nextLabel)
      @visit(clause.consequent)
      nextLabel.mark()
    @popLabel()
    brk.mark()
    @POP()
    @exitScope()

  ReturnStatement: (node) ->
    if node.argument
      @visit(node.argument)
      @RETV()
    else
      @RET()

  ThrowStatement: (node) ->
    super(node)
    @THROW()

  TryStatement: (node) ->
    if node.handlers.length > 1
      throw new Error('assert error')
    start = @newLabel()
    handler = @newLabel()
    finalizer = @newLabel()
    end = @newLabel()
    guard =
      start: start
      handler: if node.handlers.length then handler else null
      finalizer: if node.finalizer then finalizer else null
      end: end
    @guards.push(guard)
    start.mark()
    @visit(node.block)
    @JMP(finalizer)
    handler.mark()
    if node.handlers.length
      node.handlers[0].body.disableScope = true
      @enterScope()
      # bind error to the declared pattern
      param = node.handlers[0].param
      @declarePattern(param)
      assign =
        type: 'ExpressionStatement'
        expression:
          loc: param.loc
          type: 'AssignmentExpression'
          operator: '='
          left: param
      @visit(assign)
      @visit(node.handlers[0].body)
      @exitScope()
    finalizer.mark()
    if node.finalizer
      @visit(node.finalizer)
      if not node.handlers.length
        # return from the function so the next frame can be checked
        # for a guard
        @RET()
    end.mark()

  LetStatement: (node) ->
    # A let statement
    throw new Error('not implemented')

  DebuggerStatement: (node) -> @DEBUG()

  VariableDeclaration: (node) ->
    for decl in node.declarations
      decl.kind = node.kind
    @visit(node.declarations)

  VariableDeclarator: (node) ->
    @declarePattern(node.id, node.kind)
    if node.init
      assign =
        type: 'ExpressionStatement'
        expression:
          loc: node.loc
          type: 'AssignmentExpression'
          operator: '='
          left: node.id
          right: node.init
      @visit(assign)

  ThisExpression: (node) ->
    # A this expression
    throw new Error('not implemented')

  ArrayExpression: (node) ->
    super(node)
    @ARRAY_LITERAL(node.elements.length)

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

  VmFunction: (node) ->
    fn = new Emitter([{arguments: 0}].concat(@scopes))
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
    fn.visit(node.body.body)
    script = fn.end()
    functionIndex = @scripts.length
    @scripts.push(script)
    if node.isExpression
      # push function on the stack
      @FUNCTION(functionIndex)
    if node.declare
      # declare so the function will be bound at the beginning of the context
      @declareFunction(node.declare, functionIndex)

  FunctionDeclaration: (node) ->
    node.isExpression = false
    node.declare = node.id.name
    @VmFunction(node)

  FunctionExpression: (node) ->
    node.isExpression = true
    node.declare = false
    @VmFunction(node)

  SequenceExpression: (node) ->
    for i in [0...node.expressions.length - 1]
      @visit(node.expressions[i])
      @POP()
    @visit(node.expressions[i])

  UnaryExpression: (node) ->
    super(node)
    @[unaryOp[node.operator]]()

  BinaryExpression: (node) ->
    super(node)
    @[binaryOp[node.operator]]()

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

  ConditionalExpression: (node) -> @IfStatement(node)

  NewExpression: (node) ->
    # A new expression.
    throw new Error('not implemented')

  CallExpression: (node) ->
    @visit(node.arguments) # push arguments
    if node.callee.type is 'MemberExpression'
      @visit(node.callee.object) # push target
      @SR1() # save target
      @LR1() # load target
      @visitProperty(node.callee) # push property
      @CALLM(node.arguments.length)
    else
      @visit(node.callee)
      @CALL(node.arguments.length)

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

  AssignmentExpression: (node) ->
    if node.right
      if node.right.type is 'MemberExpression' and not node.right.object
        # destructuring pattern, need to adjust the stack before
        # getting the value
        @SR3()
        @visitProperty(node.right)
        @LR3()
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
            childAssignment =
              operator: node.operator
              type: 'AssignmentExpression'
              left: element
              right:
                type: 'MemberExpression'
                # omit the object since its already loaded on stack
                property: {type: 'Literal', value: index}
            @visit(childAssignment)
            @POP()
          index++
      else
        for property in node.left.properties
          @DUP()
          source = property.key
          target = property.value
          childAssignment =
            operator: node.operator
            type: 'AssignmentExpression'
            left: target
            right:
              type: 'MemberExpression'
              computed: true
              property: {type: 'Literal', value: source.name}
          @visit(childAssignment)
          @POP()
      return
    @SR3() # save new value
    if node.left.type is 'MemberExpression'
      @visitProperty(node.left)
      @SR1()
      @visit(node.left.object)
      @SR2()
      if node.operator isnt '='
        @LR1()
        @LR2()
        @GET() # get current value
        @SR4() # save current value
        @LR3() # load new value
        @LR4() # load current value
        # apply operator
        @[binaryOp[node.operator.slice(0, node.operator.length - 1)]]()
        @LR1() # load property
        @LR2() # load object
        @SET() # set
      else
        @LR3() # load value
        @LR1() # load property
        @LR2() # load object
        @SET()
    else
      if node.operator != '='
        @scopeGet(node.left.name)
        @SR4() # save current value
        @LR3() # load new value
        @LR4() # load current value
        # apply operator
        @[binaryOp[node.operator.slice(0, node.operator.length - 1)]]()
      else
        @LR3() # load new value
      @scopeSet(node.left.name) # set value

  UpdateExpression: (node) ->
    if node.argument.type is 'MemberExpression'
      @visitProperty(node.argument)
      @SR1()
      @visit(node.argument.object)
      @SR2()
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

  YieldExpression: (node) ->
    # A yield expression
    throw new Error('not implemented')

  ComprehensionExpression: (node) ->
    # An array comprehension. The blocks array corresponds to the sequence
    # of for and for each blocks. The optional filter expression corresponds
    # to the final if clause, if present
    throw new Error('not implemented')

  GeneratorExpression: (node) ->
    # A generator expression. As with array comprehensions, the blocks
    # array corresponds to the sequence of for and for each blocks, and
    # the optional filter expression corresponds to the final if clause,
    # if present.
    throw new Error('not implemented')

  GraphExpression: (node) ->
    # A graph expression, aka "sharp literal," such as #1={ self: #1# }.
    throw new Error('not implemented')

  GraphIndexExpression: (node) ->
    # A graph index expression, aka "sharp variable," such as #1#
    throw new Error('not implemented')

  LetExpression: (node) ->
    # A let expression
    throw new Error('not implemented')

  ComprehensionBlock: (node) ->
    # A for or for each block in an array comprehension or generator expression
    throw new Error('not implemented')

  Identifier: (node) ->
    # An identifier. Note that an identifier may be an expression or a
    # destructuring pattern.
    @scopeGet(node.name)

  Literal: (node) ->
    @LITERAL(node.value)


class Label
  constructor: (@instructions) ->
    @ip = null

  mark: -> @ip = @instructions.length


class Script
  constructor: (@instructions, @scripts, @localNames, @localLength,
    @guards, @stackSize)->


(->
  # create an Emitter method for each opcode
  for opcode in opcodes
    do (opcode) ->
      opcodes[opcode::name] = opcode
      # also add a method for resolving label addresses
      opcode::normalizeLabels = ->
        if @args
          for i in [0...@args.length]
            if @args[i] instanceof Label
              if @args[i].ip is null
                throw new Error('label has not been marked')
              # its a label, replace with the instruction pointer
              @args[i] = @args[i].ip
      Emitter::[opcode::name] = (args...) ->
        if not args.length
          args = null
        @instructions.push(new opcode(args))
)()


unaryOp =
  '-': 'INV'
  '!': 'LNOT'
  '~': 'NOT'
  'typeof': null
  'void': null
  'delete': null


binaryOp =
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
  'instanceof': 'INSTANCE_OF'


assignOp =
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


module.exports = Emitter
