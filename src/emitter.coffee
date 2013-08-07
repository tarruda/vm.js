esprima = require 'esprima'

AstVisitor = require './ast_visitor'
opcodes = require './opcodes'

# Last visitor applied in the compilation pipeline, it
# emits opcodes to be executed in the vm
class Emitter extends AstVisitor
  constructor: ->
    @instructions = []
    @labels = []
    @scripts = []
    @vars = {}
    @guards = []

  newLabel: -> new Label(@instructions)

  label: (name) ->
    if !name
      return @labels[@labels.length - 1]
    for label in @labels
      if label.name == name
        return label
    return null

  pushLabel: (name, stmt, brk, cont) ->
    @labels.push({name: name, stmt: stmt, brk: brk, cont: cont})

  popLabel: -> @labels.pop()
    
  declareVar: (name) -> @vars[name] = null

  declareFunction: (name, index) ->
    # a function is declared by binding a name to the function ref
    # before other statements that are not function declarations
    codes = [
      new opcodes.FUNCTION([index])
      new opcodes.LITERAL([name])
      new opcodes.SCOPE([])
      new opcodes.SET([])
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
    return new Script(@instructions, @scripts, @vars, @guards)

  VmIterProperties: (node) ->
    @visit(node.object)
    @ITER_PROPS()

  VmLoop: (node) ->
    currentLabel = @label()
    start = @newLabel()
    cont = @newLabel()
    if currentLabel?.stmt == node
      brk = currentLabel.brk
      currentLabel.cont = cont
    else
      pop = true
      brk = @newLabel()
      @pushLabel(null, node, brk, cont)
    if node.init
      @visit(node.init)
      if node.init.type != 'VariableDeclaration'
        @POP()
    if node.update
      start.mark()
    else
      cont.mark()
    if node.beforeTest
      @visit(node.beforeTest)
      @JMPF(brk)
    @visit(node.body)
    if node.update
      cont.mark()
      @visit(node.update)
      @POP()
      @JMP(start)
    if node.afterTest
      @visit(node.afterTest)
      @JMPF(brk)
    @JMP(cont)
    if pop
      brk.mark()
      @popLabel()

  ExpressionStatement: (node) ->
    super(node)
    # remove the expression value from the stack and save it
    @SREXP()

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
    # A switch statement. The lexical flag is metadata indicating whether
    # the switch statement contains any unnested let declarations
    # (and therefore introduces a new lexical scope)
    throw new Error('not implemented')

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
      @visit(node.handlers[0].body)
    finalizer.mark()
    if node.finalizer
      @visit(node.finalizer)
      if !node.handlers.length
        # return from the function so the next frame can be checked
        # for a guard
        @RET()
    end.mark()

  LetStatement: (node) ->
    # A let statement
    throw new Error('not implemented')

  DebuggerStatement: (node) -> @DEBUG()

  VariableDeclaration: (node) ->
    for v in node.declarations
      @declareVar(v.id.name)
      if v.init
        assign =
          type: 'ExpressionStatement'
          expression:
            loc: v.loc
            type: 'AssignmentExpression'
            operator: '='
            left: v.id
            right: v.init
        @visit(assign)

  ThisExpression: (node) ->
    # A this expression
    throw new Error('not implemented')

  ArrayExpression: (node) ->
    super(node)
    @ARRAY_LITERAL(node.elements.length)

  ObjectExpression: (node) ->
    for property in node.properties
      if property.kind == 'init' # object literal
        @visit(property.value)
        if property.key.type == 'Literal'
          @visit(property.key)
        else # identifier. use the name to create a literal string
          @visit({type: 'Literal', value: property.key.name})
      else
        throw new Error("property kind '#{property.kind}' not implemented")
    @OBJECT_LITERAL(node.properties.length)

  VmRestParam: (node) -> @REST(node.index, node.name)

  VmFunction: (node) ->
    fn = new Emitter()
    # load the the 'arguments' object into the local scope
    fn.LITERAL('arguments')
    fn.SCOPE()
    fn.SET()
    fn.POP()
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
    if node.operator == '||'
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
    if isMethod = (node.callee.type == 'MemberExpression')
      @visitProperty(node.callee) # push property
      @visit(node.callee.object) # push target
      @SR1() # save target
      @LR1() # load target
      @GET() # get function
      @LR1() # load target
    else
      @visit(node.callee)
    @CALL(node.arguments.length, isMethod)

  visitProperty: (memberExpression) ->
    if memberExpression.computed
      @visit(memberExpression.property)
    else if memberExpression.property.type == 'Identifier'
      @LITERAL(memberExpression.property.name)
    else if memberExpression.property.type == 'Literal'
      @LITERAL(memberExpression.property.value)
    else
      throw new Error('invalid assert')

  MemberExpression: (node) ->
    @visitProperty(node)
    @visit(node.object)
    @GET()

  AssignmentExpression: (node) ->
    if node.left.type in ['ArrayPattern', 'ObjectPattern']
      @visit(node.right)
      if node.left.type == 'ArrayPattern'
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
    if node.right.type == 'MemberExpression' && !node.right.object
      # destructuring pattern, need to adjust the stack before
      # getting the value
      @SR3()
      @visitProperty(node.right)
      @LR3()
      @GET()
    else
      @visit(node.right)
    @SR3() # save new value
    if node.left.type == 'MemberExpression'
      @visitProperty(node.left)
      @SR1()
      @visit(node.left.object)
      @SR2()
    else
      @LITERAL(node.left.name)
      @SR1()
      @SCOPE()
      @SR2()
    if node.operator != '='
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

  UpdateExpression: (node) ->
    if node.argument.type == 'MemberExpression'
      @visitProperty(node.left)
      @SR1()
      @visit(node.left.object)
      @SR2()
    else
      @LITERAL(node.argument.name)
      @SR1()
      @SCOPE()
      @SR2()
    @LR1()
    @LR2()
    @GET() # get current
    @SR3() # save current
    @LR3() # load current
    if node.operator == '++' then @INC() else @DEC()
    @LR1() # load property
    @LR2() # load object
    @SET()
    if !node.prefix
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

  # Patterns:

  # JavaScript 1.7 introduced destructuring assignment and binding
  # forms. All binding forms (such as function parameters, variable
  # declarations, and catch block headers), accept array and object
  # destructuring patterns in addition to plain identifiers. The left-hand
  # sides of assignment expressions can be arbitrary expressions, but in the
  # case where the expression is an object or array literal, it is interpreted
  # by SpiderMonkey as a destructuring pattern.

  # Since the left-hand side of an assignment can in general be any expression,
  # in an assignment context, a pattern can be any expression. In binding
  # positions (such as function parameters, variable declarations, and catch
  # headers), patterns can only be identifiers in the base case, not arbitrary
  # expressions
  ObjectPattern: (node) ->
    # An object-destructuring pattern. A literal property in an object pattern
    # can have either a string or number as its value.
    throw new Error('not implemented')

  ArrayPattern: (node) ->
    # An array-destructuring pattern.
    throw new Error('not implemented')

  # Clauses
  SwitchCase: (node) ->
    # A case (if test is an Expression) or default (if test === null) clause in
    # the body of a switch statement.
    throw new Error('not implemented')

  ComprehensionBlock: (node) ->
    # A for or for each block in an array comprehension or generator expression
    throw new Error('not implemented')

  # Miscellaneous
  Identifier: (node) ->
    # An identifier. Note that an identifier may be an expression or a
    # destructuring pattern.
    @LITERAL(node.name)
    @SCOPE()
    @GET()

  Literal: (node) ->
    @LITERAL(node.value)


class Label
  constructor: (@instructions) ->
    @ip = null

  mark: -> @ip = @instructions.length


class Script
  constructor: (@instructions, @scripts, @vars, @guards)->


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
              if @args[i].ip == null
                throw new Error('label has not been marked')
              # its a label, replace with the instruction pointer
              @args[i] = @args[i].ip
      Emitter::[opcode::name] = (args...) ->
        if !args.length
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
