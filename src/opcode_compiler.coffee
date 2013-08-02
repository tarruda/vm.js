Script = require './script'
{
  NOOP, POP, DUP2, PUSHS, SAVE, INV, LNOT, NOT, INCP, DECP, INCS, DECS, GET,
  ADD, SUB, MUL, DIV, MOD, SHL, SAR, SHR, OR, AND, XOR, CEQ, CNEQ, CID, CNID,
  LT, LTE, GT, GTE, IN, INSOF, LOR, LAND, SET, LIT, OLIT, ALIT
} = require './opcodes'

prefixUnaryOp =
  '-': INV
  '+': NOOP
  '!': LNOT
  '~': NOT
  'typeof': null
  'void': null
  'delete': null
  '++': INCP
  '--': DECP

postfixUnaryOp =
  '++': INCS
  '--': DECS

binaryOp =
  '==': CEQ
  '!=': CNEQ
  '===': CID
  '!==': CNID
  '<': LT
  '<=': LTE
  '>': GT
  '>=': GTE
  '||': LOR
  '&&': LAND
  '<<': SHL
  '>>': SAR
  '>>>': SHR
  '+': ADD
  '-': SUB
  '*': MUL
  '/': DIV
  '%': MOD
  '|': OR
  '&': AND
  '^': XOR
  'in': IN
  'instanceof': INSOF
  '..': null # e4x-specific

assignOp =
  '+=': ADD
  '-=': SUB
  '*=': MUL
  '/=': DIV
  '%=': MOD
  '<<=': SHL
  '>>=': SAR
  '>>>=': SHR
  '|=': OR
  '&=': AND
  '^=': XOR

# AST node types. Source:
# https://developer.mozilla.org/en-US/docs/SpiderMonkey/Parser_API
emit =
  # Programs:
  Program: (node, script) ->
    # A complete program source tree.
    for child in node.body
      emit[child.type](child, script)
  Function: (node, script) ->
    # A function declaration or expression. The body of the function may be a
    # block statement, or in the case of an expression closure, an expression.
    throw new Error('not implemented')

  # Statements:
  EmptyStatement: (node, script) ->
    # An empty statement, i.e., a solitary semicolon.
    throw new Error('not implemented')
  BlockStatement: (node, script) ->
    # A block statement, i.e., a sequence of statements surrounded by braces.
    throw new Error('not implemented')
  ExpressionStatement: (node, script) ->
    # An expression statement, i.e., a statement consisting of a single
    # expression.
    emit[node.expression.type](node.expression, script)
    SAVE(script)
  IfStatement: (node, script) ->
    # An if statement.
    throw new Error('not implemented')
  LabeledStatement: (node, script) ->
    # A labeled statement, i.e., a statement prefixed by a break/continue labe
    throw new Error('not implemented')
  BreakStatement: (node, script) ->
    # A break statement
    throw new Error('not implemented')
  ContinueStatement: (node, script) ->
    # A continue statement
    throw new Error('not implemented')
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
    # A while statement
    throw new Error('not implemented')
  DoWhileStatement: (node, script) ->
    # A do/while statement
    throw new Error('not implemented')
  ForStatement: (node, script) ->
    # A for statement
    throw new Error('not implemented')
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
    # A function declaration
    throw new Error('not implemented')
  VariableDeclaraction: (node, script) ->
    # A variable declaration, via one of var, let, or const.
    # TODO incomplete
    for child in node.declarations
      emit[child.type](child.init, script)
  VariableDeclarator: (node, script) ->
    # A variable declarator
    emit[node.init.type](node.init, script)
    SAVE(script, node.name)

  # Expressions:
  ThisExpression: (node, script) ->
    # A this expression
    throw new Error('not implemented')
  ArrayExpression: (node, script) ->
    for element in node.elements
      emit[element.type](element, script)
    ALIT(script, node.elements.length)
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
    OLIT(script, node.properties.length)
  FunctionExpression: (node, script) ->
    # A function expression
    throw new Error('not implemented')
  ArrowExpression: (node, script) ->
    # A fat arrow function expression, i.e.,`let foo = (bar) => { /* body */ }`
    throw new Error('not implemented')
  SequenceExpression: (node, script) ->
    # A sequence expression, i.e., a comma-separated sequence of expressions.
    throw new Error('not implemented')
  UnaryExpression: (node, script) ->
    emit[node.argument.type](node.argument, script)
    if node.prefix then prefixUnaryOp[node.operator](script)
    else suffixUnaryOp[node.operator](script)
  BinaryExpression: (node, script) ->
    # A binary operator expression.
    emit[node.left.type](node.left, script)
    emit[node.right.type](node.right, script)
    binaryOp[node.operator](script)
  AssignmentExpression: (node, script) ->
    if node.left.type == 'MemberExpression'
      # push property owner to stack
      emit[node.left.object.type](node.left.object, script)
      # push property key to stack
      if node.left.computed
        emit[node.left.property.type](node.left.property, script)
      else
        LIT(script, node.left.property.name)
    else if node.left.type == 'Identifier'
      PUSHS(script) # push local scope to stack
      LIT(script, node.left.name)
    # push value to be set
    if node.operator == '=' # simple assignment
      emit[node.right.type](node.right, script)
      SET(script)
    else # get the value, apply the operation then assign
      DUP2(script)
      GET(script)
      emit[node.right.type](node.right, script)
      assignOp[node.operator](script)
      SET(script)
  UpdateExpression: (node, script) ->
    # An update (increment or decrement) operator expression.
    throw new Error('not implemented')
  LogicalExpression: (node, script) ->
    # A logical binary operator expression.
    emit[node.left.type](node.left, script)
    emit[node.right.type](node.right, script)
    binaryOp[node.operator](script)
  ConditionalExpression: (node, script) ->
    # A conditional expression, i.e., a ternary ?/: expression
    throw new Error('not implemented')
  NewExpression: (node, script) ->
    # A new expression.
    throw new Error('not implemented')
  CallExpression: (node, script) ->
    # A function or method call expression.
    throw new Error('not implemented')
  MemberExpression: (node, script) ->
    emit[node.object.type](node.object, script)
    if node.computed # computed at runtime, eg: x[y]
      emit[node.property.type](node.property, script)
    else # static member eg: x.y
      LIT(script, node.property.name)
    GET(script)
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
    PUSHS(script)
    LIT(script, node.name)
    GET(script)
  Literal: (node, script) ->
    LIT(script, node.value)

compile = (node) ->
  script = new Script()
  emit[node.type](node, script)
  return script

module.exports = compile

