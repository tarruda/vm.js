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
    @rest = null

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
      new opcodes.SCOPE([])
      new opcodes.LITERAL([name])
      new opcodes.FUNCTION([index])
      new opcodes.SET([])
    ]
    @instructions = codes.concat(@instructions)

  end: ->
    for code in @instructions
      code.normalizeLabels()
    if !(@instructions[@instructions.length - 1] instanceof opcodes.RET)
      this.RET()
    return new Script(@instructions, @scripts, @vars, @rest)

  ExpressionStatement: (node) ->
    super(node)
    # remove the expression value from the stack and save it
    @SAVE('_lastExpression')

  IfStatement: (node) ->
    ifTrue = new Label(@instructions)
    end = new Label(@instructions)
    @visit(node.test)
    @JMPT(ifTrue)
    @visit(node.alternate)
    @JMP(end)
    ifTrue.mark()
    @visit(node.consequent)
    end.mark()

  LabeledStatement: (node) ->
    brk = new Label(@instructions)
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
    super(node)
    @RET()

  ThrowStatement: (node) ->
    # A throw statement
    throw new Error('not implemented')

  TryStatement: (node) ->
    # A try statement
    throw new Error('not implemented')

  VmLoop: (node) ->
    currentLabel = @label()
    start = new Label(@instructions)
    cont = new Label(@instructions)
    if currentLabel?.stmt == node
      brk = currentLabel.brk
      currentLabel.cont = cont
    else
      pop = true
      brk = new Label(@instructions)
      @pushLabel(null, node, brk, cont)
    if node.init
      @visit(node.init)
      if node.init.type != 'VmVariableDeclaration'
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

  LetStatement: (node) ->
    # A let statement
    throw new Error('not implemented')

  DebuggerStatement: (node) -> @DEBUG()

  VmVariableDeclaration: (node) -> @declareVar(node.name)

  ThisExpression: (node) ->
    # A this expression
    throw new Error('not implemented')

  ArrayExpression: (node) ->
    super(node)
    @ARRAY_LITERAL(node.elements.length)

  ObjectExpression: (node) ->
    for property in node.properties
      if property.kind == 'init' # object literal
        if property.key.type == 'Literal'
          @visit(property.key)
        else # identifier. use the name to create a literal string
          @visit({type: 'Literal', value: property.key.name})
        @visit(property.value)
      else
        throw new Error("property kind '#{property.kind}' not implemented")
    @OBJECT_LITERAL(node.properties.length)

  VmRestParamInit: (node) -> @REST_INIT(node.index, node.name)

  VmFunction: (node) ->
    fn = new Emitter()
    # load the the 'arguments' object into the local scope
    fn.SAVE('_args')
    fn.SCOPE()
    fn.LITERAL('arguments')
    fn.PULL('_args')
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
    for expression in node.expressions
      @visit(expression)
      @SAVE('_lastExpression')
    @PULL('_lastExpression')

  UnaryExpression: (node) ->
    super(node)
    @[unaryOp[node.operator]]()

  BinaryExpression: (node) ->
    super(node)
    @[binaryOp[node.operator]]()

  VmSaveStatement: (node) ->
    @visit(node.value)
    @SAVE(node.name)

  VmLoadExpression: (node) -> @LOAD(node.name)

  VmPullExpression: (node) -> @PULL(node.name)

  VmAssignmentExpression: (node) ->
    if node.left.type == 'MemberExpression'
      # push property owner
      @visit(node.left.object)
      # push property key
      if node.left.computed
        @visit(node.left.property)
      else
        @LITERAL(node.left.property.name)
    else
      @SCOPE() # push local scope
      @LITERAL(node.left.name) # push local variable name
    @visit(node.right) # push property value
    @SET()

  LogicalExpression: (node) ->
    evalEnd = new Label(@instructions)
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
    if isMethod = (node.callee.type == 'MemberExpression')
      @visit(node.callee.object)
      @SAVE('_target')
      @LOAD('_target')
      @visit(node.arguments)
      @PULL('_target')
      if node.callee.property.computed
        @visit(node.callee.property)
      else
        @LITERAL(node.callee.property.name)
      @GET()
    else
      super(node)
    @CALL(node.arguments.length, isMethod)

  MemberExpression: (node) ->
    if node.object
      @visit(node.object)
    if node.computed # computed at runtime, eg: x[y]
      @visit(node.property)
    else # static member eg: x.y
      @LITERAL(node.property.name)
    @GET()

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

  CatchClause: (node) ->
    # A catch clause following a try block. The optional guard property
    # corresponds to the optional expression guard on the bound variable.
    throw new Error('not implemented')

  ComprehensionBlock: (node) ->
    # A for or for each block in an array comprehension or generator expression
    throw new Error('not implemented')

  # Miscellaneous
  Identifier: (node) ->
    # An identifier. Note that an identifier may be an expression or a
    # destructuring pattern.
    @SCOPE()
    @LITERAL(node.name)
    @GET()

  Literal: (node) ->
    @LITERAL(node.value)


class Label
  constructor: (@instructions) ->
    @ip = null

  mark: -> @ip = @instructions.length


class Script
  constructor: (@instructions, @scripts, @vars, @rest)->


(->
  # create an Emitter method for each opcode
  for opcode in opcodes
    do (opcode) ->
      opcodes[opcode::name] = opcode
      # also add a method for resolving label addresses
      opcode::normalizeLabels = ->
        for i in [0...@argc]
          if @args[i] instanceof Label
            if @args[i].ip == null
              throw new Error('label has not been marked')
            # its a label, replace with the instruction pointer
            @args[i] = @args[i].ip
      Emitter::[opcode::name] = (args...) ->
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
