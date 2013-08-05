esprima = require 'esprima'

opcodes = require './opcodes'
ConstantFolder = require './constant_folder'

class Compiler
  constructor: (@transformers...) ->
    @instructions = []
    @loops = []
    @scripts = []
    @vars = {}
    @rest = null

  label: -> new Label(@instructions)

  pushLoop: (labels) -> @loops.push(labels)

  popLoop: (labels) -> @loops.pop()

  loopStart: -> @loops[@loops.length - 1].start

  loopEnd: -> @loops[@loops.length - 1].end

  declareVar: (name) -> @vars[name] = null

  declareFunction: (name, index) ->
    # a function is declared by binding a name to the function ref
    # before other statements that are not function declarations
    codes = [
      new opcodes.FUNCTION([index])
      new opcodes.SCOPE([])
      new opcodes.LITERAL([name])
      new opcodes.SET([])
    ]
    @instructions = codes.concat(@instructions)

  end: ->
    for code in @instructions
      code.normalizeLabels()
    if !(@instructions[@instructions.length - 1] instanceof opcodes.RET)
      this.RET()
    return new Script(@instructions, @scripts, @vars, @rest)

  emit: (node) ->
    for transformer in @transformers
      if transformer[node.type]
        node = transformer[node.type](node)
    @[node.type](node)
    return this

  Program: (node) ->
    for child in node.body
      @emit(child)
    # @instructions.pop() # remove RET

  EmptyStatement: ->

  BlockStatement: (node) ->
    for child in node.body
      @emit(child)

  ExpressionStatement: (node) ->
    @emit(node.expression)
    # remove the expression value from the stack and save it
    @SAVE()

  IfStatement: (node) ->
    # An if statement.
    throw new Error('not implemented')

  LabeledStatement: (node) ->
    # A labeled statement, i.e., a statement prefixed by a break/continue labe
    throw new Error('not implemented')

  BreakStatement: (node) ->
    @JMP(@loopEnd())

  ContinueStatement: (node) ->
    @JMP(@loopStart())

  WithStatement: (node) ->
    # A with statement
    throw new Error('not implemented')

  SwitchStatement: (node) ->
    # A switch statement. The lexical flag is metadata indicating whether
    # the switch statement contains any unnested let declarations
    # (and therefore introduces a new lexical scope)
    throw new Error('not implemented')

  ReturnStatement: (node) ->
    if node.argument
      @emit(node.argument)
    @RET()

  ThrowStatement: (node) ->
    # A throw statement
    throw new Error('not implemented')

  TryStatement: (node) ->
    # A try statement
    throw new Error('not implemented')

  WhileStatement: (node) ->
    loopStart = @label()
    loopEnd = @label()
    @pushLoop({start: loopStart, end: loopEnd})
    loopStart.mark()
    @emit(node.test)
    @JMPF(loopEnd)
    @emit(node.body)
    @JMP(loopStart)
    loopEnd.mark()
    @popLoop()

  DoWhileStatement: (node) ->
    loopStart = @label()
    loopEnd = @label()
    @pushLoop({start: loopStart, end: loopEnd})
    loopStart.mark()
    @emit(node.body)
    @emit(node.test)
    @JMPT(loopStart)
    loopEnd.mark()
    @popLoop()

  ForStatement: (node) ->
    loopStart = @label()
    loopEnd = @label()
    @pushLoop({start: loopStart, end: loopEnd})
    @emit(node.init)
    if node.init.type != 'VariableDeclaration'
      @POP()
    loopStart.mark()
    @emit(node.test)
    @JMPF(loopEnd)
    @emit(node.body)
    @emit(node.update)
    @POP()
    @JMP(loopStart)
    loopEnd.mark()
    @popLoop()

  ForInStatement: (node) ->
    # A for/in statement, or, if each is true, a for each/in statement
    throw new Error('not implemented')
  ForOfStatement: (node) ->
    # A for/of statement
    throw new Error('not implemented')
  LetStatement: (node) ->
    # A let statement
    throw new Error('not implemented')
  DebuggerStatement: (node) ->
    # A debugger statement
    throw new Error('not implemented')

  FunctionDeclaration: (node) ->
    # reuse the FunctionExpression emitter
    expr =
      loc: node.loc
      type: 'FunctionExpression'
      id: node.id
      params: node.params
      defaults: node.defaults
      rest: node.rest
      generator: node.generator
      expression: node.expression
      body: node.body
    @emit(expr)
    # when declaring we don't need push the function object into the stack
    # so remove the last instruction which is responsible for doing this
    @instructions.pop()

  VariableDeclaration: (node) ->
    for child in node.declarations
      @emit(child)

  VariableDeclarator: (node) ->
    # A variable declarator
    @declareVar(node.id.name)
    assignNode =
      loc: node.loc
      type: 'AssignmentExpression'
      operator: '='
      left: node.id
      right: node.init
    @emit(assignNode)
    @POP()

  ThisExpression: (node) ->
    # A this expression
    throw new Error('not implemented')

  ArrayExpression: (node) ->
    for element in node.elements
      @emit(element)
    @ARRAY_LITERAL(node.elements.length)

  ObjectExpression: (node) ->
    for property in node.properties
      if property.kind == 'init' # object literal
        if property.key.type == 'Literal'
          @emit(property.key)
        else # identifier. use the name to create a literal string
          @emit({type: 'Literal', value: property.key.name})
        @emit(property.value)
      else
        throw new Error("property kind '#{property.kind}' not implemented")
    @OBJECT_LITERAL(node.properties.length)

  FunctionExpression: (node) ->
    fn = new Compiler()
    # assign the 'arguments' object
    fn.SCOPE()
    fn.LITERAL('arguments')
    fn.SET()
    fn.POP()
    # declare/emit arguments initialization
    len = node.params.length
    for i in [0...len]
      param = node.params[i]
      def = node.defaults[i]
      if param.type != 'Identifier' then throw new Error('assert error')
      declare = esprima.parse("var #{param.name} = arguments[#{i}] || 0")
      declare = declare.body[0].declarations[0]
      if def then declare.init.right = def
      else declare.init = declare.init.left
      fn.emit(declare)
    if node.rest
      fn.rest = node.rest.name
      rest = esprima.parse("var #{node.rest.name} = null;")
      rest = rest.body[0].declarations[0]
      fn.emit(rest)
      fn.INIT_REST(len)
    # emit function body
    for child in node.body.body
      fn.emit(child)
    script = fn.end()
    functionIndex = @scripts.length
    @scripts.push(script)
    # push the function on the stack
    @FUNCTION(functionIndex)
    if node.id # declare if it has a name
      @declareFunction(node.id.name, functionIndex)

  ArrowExpression: (node) ->
    # A fat arrow function expression, i.e.,`let foo = (bar) => { /* body */ }`
    throw new Error('not implemented')

  SequenceExpression: (node) ->
    for expression in node.expressions
      @emit(expression)
      @SAVE()
    @LOAD()

  UnaryExpression: (node) ->
    @emit(node.argument)
    @[unaryOp[node.operator]]()

  BinaryExpression: (node) ->
    @emit(node.left)
    @emit(node.right)
    @[binaryOp[node.operator]]()

  AssignmentExpression: (node) ->
    @emit(node.right)
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
              computed: true
              property: {type: 'Literal', value: index}
          @emit(childAssignment)
          @POP()
        index++
      return
    if node.left.type == 'ObjectPattern'
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
            # omit the object since its already loaded on stack
            computed: true
            property: {type: 'Literal', value: source.name}
        @emit(childAssignment)
        @POP()
      return
    if node.left.type == 'MemberExpression'
      # push property owner to stack
      @emit(node.left.object)
      # push property key to stack
      if node.left.computed
        @emit(node.left.property)
      else
        @LITERAL(node.left.property.name)
    else # Identifier
      @SCOPE() # push local scope to stack
      @LITERAL(node.left.name) # push key to stack
    if node.operator != '='
      @DUP2()
      @SAVE2()
      @GET()
      @SWAP()
      @[assignOp[node.operator]]() # execute operation
      @LOAD2()
    @SET()

  UpdateExpression: (node) ->
    assignNode =
      type: 'AssignmentExpression'
      operator: if node.operator == '++' then '+=' else '-='
      left: node.argument
      right: {type: 'Literal', value: 1}
    if node.prefix
      @emit(assignNode)
    else
      @emit(node.argument)
      @emit(assignNode)
      @POP()

  LogicalExpression: (node) ->
    # A logical binary operator expression.
    @emit(node.left)
    @emit(node.right)
    @[binaryOp[node.operator]]()

  ConditionalExpression: (node) ->
    ifTrue = @label()
    end = @label()
    @emit(node.test)
    @JMPT(ifTrue)
    @emit(node.alternate)
    @JMP(end)
    ifTrue.mark()
    @emit(node.consequent)
    end.mark()

  NewExpression: (node) ->
    # A new expression.
    throw new Error('not implemented')

  CallExpression: (node) ->
    for argument in node.arguments
      @emit(argument)
    @emit(node.callee)
    @CALL(node.arguments.length)

  MemberExpression: (node) ->
    if node.object
      @emit(node.object)
    if node.computed # computed at runtime, eg: x[y]
      @emit(node.property)
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
  # create a Compiler method for each opcode
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
      Compiler::[opcode::name] = (args...) ->
        @instructions.push(new opcode(args))
)()

unaryOp =
  '-': 'INV'
  '+': 'NOOP'
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
  '||': 'LOR'
  '&&': 'LAND'
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

module.exports = (ast) ->
  compiler = new Compiler(new ConstantFolder())
  compiler.emit(ast)
  return compiler.end()
