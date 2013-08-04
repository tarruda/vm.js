Script = require './script'

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

# AST node types. Source:
# https://developer.mozilla.org/en-US/docs/SpiderMonkey/Parser_API
emit =
  # Programs:
  Program: (node) ->
    program = new Script()
    for child in node.body
      emit[child.type](child, program)
    program.end()
    program.instructions.pop() # remove RET
    return program

  # Statements:
  
  EmptyStatement: (node, script) ->

  BlockStatement: (node, script) ->
    script.pushBlock()
    for child in node.body
      emit[child.type](child, script)
    script.popBlock()

  ExpressionStatement: (node, script) ->
    emit[node.expression.type](node.expression, script)
    script.SAVE()

  IfStatement: (node, script) ->
    # An if statement.
    throw new Error('not implemented')

  LabeledStatement: (node, script) ->
    # A labeled statement, i.e., a statement prefixed by a break/continue labe
    throw new Error('not implemented')

  BreakStatement: (node, script) ->
    script.JMP(script.loopEnd())

  ContinueStatement: (node, script) ->
    script.JMP(script.loopStart())

  WithStatement: (node, script) ->
    # A with statement
    throw new Error('not implemented')

  SwitchStatement: (node, script) ->
    # A switch statement. The lexical flag is metadata indicating whether
    # the switch statement contains any unnested let declarations
    # (and therefore introduces a new lexical scope)
    throw new Error('not implemented')
  ReturnStatement: (node, script) ->
    # A return statement
    throw new Error('not implemented')
  ThrowStatement: (node, script) ->
    # A throw statement
    throw new Error('not implemented')
  TryStatement: (node, script) ->
    # A try statement
    throw new Error('not implemented')
  WhileStatement: (node, script) ->
    loopStart = script.label()
    loopEnd = script.label()
    script.pushLoop({start: loopStart, end: loopEnd})
    loopStart.mark()
    emit[node.test.type](node.test, script)
    script.JMPF(loopEnd)
    emit[node.body.type](node.body, script)
    script.JMP(loopStart)
    loopEnd.mark()
    script.popLoop()

  DoWhileStatement: (node, script) ->
    loopStart = script.label()
    loopEnd = script.label()
    script.pushLoop({start: loopStart, end: loopEnd})
    loopStart.mark()
    emit[node.body.type](node.body, script)
    emit[node.test.type](node.test, script)
    script.JMPT(loopStart)
    loopEnd.mark()
    script.popLoop()

  ForStatement: (node, script) ->
    loopStart = script.label()
    loopEnd = script.label()
    script.pushLoop({start: loopStart, end: loopEnd})
    emit[node.init.type](node.init, script)
    script.POP() if node.init.type != 'VariableDeclaration'
    loopStart.mark()
    emit[node.test.type](node.test, script)
    script.JMPF(loopEnd)
    emit[node.body.type](node.body, script)
    emit[node.update.type](node.update, script)
    script.POP()
    script.JMP(loopStart)
    loopEnd.mark()
    script.popLoop()

  ForInStatement: (node, script) ->
    # A for/in statement, or, if each is true, a for each/in statement
    throw new Error('not implemented')
  ForOfStatement: (node, script) ->
    # A for/of statement
    throw new Error('not implemented')
  LetStatement: (node, script) ->
    # A let statement
    throw new Error('not implemented')
  DebuggerStatement: (node, script) ->
    # A debugger statement
    throw new Error('not implemented')

  # Declarations:
  FunctionDeclaration: (node, script) ->
    # reuse the FunctionExpression emitter
    expr =
      id: node.id
      params: node.params
      defaults: node.defaults
      rest: node.rest
      generator: node.generator
      expression: node.expression
      body: node.body
    emit.FunctionExpression(expr, script)
    # when declaring we don't need push the function object into the stack
    # so remove the last instruction which is responsible for doing this
    opcode = script.popInstruction()

  VariableDeclaration: (node, script) ->
    for child in node.declarations
      emit[child.type](child, script)

  VariableDeclarator: (node, script) ->
    # A variable declarator
    script.declareVar(node)
    assignNode =
      operator: '='
      left: node.id
      right: node.init
    emit.AssignmentExpression(assignNode, script)
    script.POP()

  # Expressions:
  ThisExpression: (node, script) ->
    # A this expression
    throw new Error('not implemented')

  ArrayExpression: (node, script) ->
    for element in node.elements
      emit[element.type](element, script)
    script.ARRAY_LITERAL(node.elements.length)
  ObjectExpression: (node, script) ->
    for property in node.properties
      if property.kind == 'init' # object literal
        if property.key.type == 'Literal'
          emit[property.key.type](property.key, script)
        else # identifier. use the name to create a literal string
          emit.Literal({value: property.key.name}, script)
        emit[property.value.type](property.value, script)
      else
        throw new Error("property kind '#{property.kind}' not implemented")
    script.OBJECT_LITERAL(node.properties.length)

  FunctionExpression: (node, script) ->
    fn = new Script()
    for child in node.body.body
      emit[child.type](child, fn)
    fn.end()
    params = []
    # use some assertions for param, default and rest node.types since
    # I don't if more types are possible
    for i in [0...node.params.length]
      param = node.params[i]
      def = node.defaults[i]
      if param.type != 'Identifier' then throw new Error('invalid param')
      param = {name: param.name, def: null}
      if def
        if def.type != 'Literal' then throw new Error('invalid default param')
        param.def = def.value
      fn.addParam(param)
    if node.nest
      if node.rest.type != 'Identifier' then throw new Error('invalid rest')
      fn.setRest(node.rest.name)
    functionIndex = script.addScript(fn)
    # push the function on the stack
    script.FUNCTION(functionIndex)
    if node.id # if it has a name, also declare it
      script.declareFunction(node.id.name, functionIndex)

  ArrowExpression: (node, script) ->
    # A fat arrow function expression, i.e.,`let foo = (bar) => { /* body */ }`
    throw new Error('not implemented')

  SequenceExpression: (node, script) ->
    for expression in node.expressions
      emit[expression.type](expression, script)
      script.SAVE()
    script.LOAD()

  UnaryExpression: (node, script) ->
    emit[node.argument.type](node.argument, script)
    script[unaryOp[node.operator]]()
  BinaryExpression: (node, script) ->
    # A binary operator expression.
    emit[node.left.type](node.left, script)
    emit[node.right.type](node.right, script)
    script[binaryOp[node.operator]]()

  AssignmentExpression: (node, script) ->
    emit[node.right.type](node.right, script)
    if node.left.type == 'ArrayPattern'
      index = 0
      for element in node.left.elements
        if element
          script.DUP()
          # get the nth-item from the array
          childAssignment =
            operator: node.operator
            type: node.type
            left: element
            right:
              type: 'MemberExpression'
              # omit the object since its already loaded on stack
              computed: true
              property: {type: 'Literal', value: index}
          emit.AssignmentExpression(childAssignment, script)
          script.POP()
        index++
      return
    if node.left.type == 'ObjectPattern'
      for property in node.left.properties
        script.DUP()
        source = property.key
        target = property.value
        childAssignment =
          operator: node.operator
          type: node.type
          left: target
          right:
            type: 'MemberExpression'
            # omit the object since its already loaded on stack
            computed: true
            property: {type: 'Literal', value: source.name}
        emit.AssignmentExpression(childAssignment, script)
        script.POP()
      return
    if node.left.type == 'MemberExpression'
      # push property owner to stack
      emit[node.left.object.type](node.left.object, script)
      # push property key to stack
      if node.left.computed
        emit[node.left.property.type](node.left.property, script)
      else
        script.LITERAL(node.left.property.name)
    else # Identifier
      script.SCOPE() # push local scope to stack
      script.LITERAL(node.left.name) # push key to stack
    if node.operator != '='
      script.DUP2()
      script.SAVE2()
      script.GET()
      script.SWAP()
      script[assignOp[node.operator]]() # execute operation
      script.LOAD2()
    script.SET()

  UpdateExpression: (node, script) ->
    assignNode =
      operator: if node.operator == '++' then '+=' else '-='
      left: node.argument
      right: {type: 'Literal', value: 1}
    if node.prefix
      emit.AssignmentExpression(assignNode, script)
    else
      emit[node.argument.type](node.argument, script)
      emit.AssignmentExpression(assignNode, script)
      script.POP()

  LogicalExpression: (node, script) ->
    # A logical binary operator expression.
    emit[node.left.type](node.left, script)
    emit[node.right.type](node.right, script)
    script[binaryOp[node.operator]]()

  ConditionalExpression: (node, script) ->
    ifTrue = script.label()
    end = script.label()
    emit[node.test.type](node.test, script)
    script.JMPT(ifTrue)
    emit[node.alternate.type](node.alternate, script)
    script.JMP(end)
    ifTrue.mark()
    emit[node.consequent.type](node.consequent, script)
    end.mark()

  NewExpression: (node, script) ->
    # A new expression.
    throw new Error('not implemented')

  CallExpression: (node, script) ->
    emit[node.callee.type](node.callee, script)
    for argument in node.arguments
      emit[argument.type](argument, script)
    script.CALL()

  MemberExpression: (node, script) ->
    if node.object then emit[node.object.type](node.object, script)
    if node.computed # computed at runtime, eg: x[y]
      emit[node.property.type](node.property, script)
    else # static member eg: x.y
      script.LITERAL(node.property.name)
    script.GET()

  YieldExpression: (node, script) ->
    # A yield expression
    throw new Error('not implemented')
  ComprehensionExpression: (node, script) ->
    # An array comprehension. The blocks array corresponds to the sequence
    # of for and for each blocks. The optional filter expression corresponds
    # to the final if clause, if present
    throw new Error('not implemented')
  GeneratorExpression: (node, script) ->
    # A generator expression. As with array comprehensions, the blocks
    # array corresponds to the sequence of for and for each blocks, and
    # the optional filter expression corresponds to the final if clause,
    # if present.
    throw new Error('not implemented')
  GraphExpression: (node, script) ->
    # A graph expression, aka "sharp literal," such as #1={ self: #1# }.
    throw new Error('not implemented')
  GraphIndexExpression: (node, script) ->
    # A graph index expression, aka "sharp variable," such as #1#
    throw new Error('not implemented')
  LetExpression: (node, script) ->
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
  ObjectPattern: (node, script) ->
    # An object-destructuring pattern. A literal property in an object pattern
    # can have either a string or number as its value.
    throw new Error('not implemented')
  ArrayPattern: (node, script) ->
    # An array-destructuring pattern.
    throw new Error('not implemented')

  # Clauses
  SwitchCase: (node, script) ->
    # A case (if test is an Expression) or default (if test === null) clause in
    # the body of a switch statement.
    throw new Error('not implemented')
  CatchClause: (node, script) ->
    # A catch clause following a try block. The optional guard property
    # corresponds to the optional expression guard on the bound variable.
    throw new Error('not implemented')
  ComprehensionBlock: (node, script) ->
    # A for or for each block in an array comprehension or generator expression
    throw new Error('not implemented')

  # Miscellaneous
  Identifier: (node, script) ->
    # An identifier. Note that an identifier may be an expression or a
    # destructuring pattern.
    script.SCOPE()
    script.LITERAL(node.name)
    script.GET()

  Literal: (node, script) ->
    script.LITERAL(node.value)

compile = (node) ->
  return emit.Program(node)

module.exports = compile

