Script = require './script'
opcodes = require './opcodes'

# compose a set of opcodes and return an object with the opcode interface
# that when applied to a script will have the effect of applying each
# opcode individually with the same args
compose = (opcodes...) ->
  rv = (script, args...) ->
    for opcode in opcodes
      opcode(script, args...)
  return rv

unaryOp =
  '-': null
  '+': null
  '!': null
  '~': null
  'typeof': null
  'void': null
  'delete': null

binaryOp =
  '==': null
  '!=': null
  '===': null
  '!==': null
  '<': null
  '<=': null
  '>': null
  '>=': null
  '<<': null
  '>>': null
  '>>>': null
  '+': opcodes.add
  '-': opcodes.sub
  '*': opcodes.mul
  '/': opcodes.div
  '%': null
  '|': null
  '^': null
  'in': null
  'instanceof': null
  '..': null

logicalOp =
  '||': null
  '&&': null

assignOp =
  '=': compose(opcodes.dup, opcodes.save)
  '+=': compose(opcodes.load, opcodes.add, opcodes.dup, opcodes.save)
  '-=': null
  '*=': null
  '/=': null
  '%=': null
  '<<=': null
  '>>=': null
  '>>>=': null
  '|=': null
  '^=': null
  '&=': null

updateOp =
  '++': null
  '--': null

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
    opcodes.store(script, node.name)
  # Expressions
  ThisExpression: (node, script) ->
    # A this expression
    throw new Error('not implemented')
  ArrayExpression: (node, script) ->
    # An array expression
    throw new Error('not implemented')
  ObjectExpression: (node, script) ->
    # An object expression. A literal property in an object expression
    # can have either a string or number as its value. Ordinary property
    # initializers have a kind value "init"; getters and setters have the
    # kind values "get" and "set", respectively.An object expression
    throw new Error('not implemented')
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
    # A unary operator expression.
    throw new Error('not implemented')
  BinaryExpression: (node, script) ->
    # A binary operator expression.
    emit[node.left.type](node.left, script)
    emit[node.right.type](node.right, script)
    binaryOp[node.operator](script)
  AssignmentExpression: (node, script) ->
    emit[node.right.type](node.right, script)
    if node.left.type == 'Identifier'
      assignOp[node.operator](script, node.left.name)

  UpdateExpression: (node, script) ->
    # An update (increment or decrement) operator expression.
    throw new Error('not implemented')
  LogicalExpression: (node, script) ->
    # A logical operator expression.
    throw new Error('not implemented')
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
    # A member expression. If computed === true, the node corresponds to
    # a computed e1[e2] expression and property is an Expression. If
    # computed === false, the node corresponds to a static e1.x
    # expression and property is an Identifier.
    throw new Error('not implemented')
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
    throw new Error('not implemented')
  Literal: (node, script) ->
    # A literal token. Note that a literal can be an expression.
    opcodes.literal(script, node.value)

compile = (node) ->
  script = new Script()
  emit[node.type](node, script)
  return script

module.exports = compile

