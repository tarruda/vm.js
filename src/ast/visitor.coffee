
# Base class for classes that perform ast transformation
# Any subclass must return a node on the type-specific methods
# or null to delete that node
class Visitor

  visit: (node) ->
    if node instanceof Array
      return @visitArray(node)
    if node and node.type
      return @[node.type](node)
    if node
      throw new Error('unexpected node')
    return null

  visitArray: (array) ->
    i = 0
    while i < array.length
      if not array[i]
        i++
        continue
      result = @visit(array[i])
      if result
        array[i++] = result
      else
        array.splice(i, 1)
    return array

  Program: (node) ->
    node.body = @visit(node.body)
    return node

  EmptyStatement: (node) -> null

  BlockStatement: (node) ->
    node.body = @visit(node.body)
    return node

  ExpressionStatement: (node) ->
    node.expression = @visit(node.expression)
    return node

  IfStatement: (node) ->
    node.test = @visit(node.test)
    node.consequent = @visit(node.consequent)
    node.alternate = @visit(node.alternate)
    return node

  LabeledStatement: (node) ->
    node.label = @visit(node.label)
    node.body = @visit(node.body)
    return node

  BreakStatement: (node) ->
    node.label = @visit(node.label)
    return node

  ContinueStatement: (node) ->
    node.label = @visit(node.label)
    return node

  WithStatement: (node) ->
    node.object = @visit(node.object)
    node.body = @visit(node.body)
    return node

  SwitchStatement: (node) ->
    node.discriminant = @visit(node.discriminant)
    node.cases = @visit(node.cases)
    return node

  ReturnStatement: (node) ->
    node.argument = @visit(node.argument)
    return node

  ThrowStatement: (node) ->
    node.argument = @visit(node.argument)
    return node

  TryStatement: (node) ->
    node.block = @visit(node.block)
    node.handlers = @visit(node.handlers)
    node.guardedHandlers = @visit(node.guardedHandlers)
    node.finalizer = @visit(node.finalizer)
    return node

  WhileStatement: (node) ->
    node.test = @visit(node.test)
    node.body = @visit(node.body)
    return node

  DoWhileStatement: (node) ->
    node.body = @visit(node.body)
    node.test = @visit(node.test)
    return node

  ForStatement: (node) ->
    node.test = @visit(node.test)
    node.body = @visit(node.body)
    node.init = @visit(node.init)
    node.update = @visit(node.update)
    return node

  ForInStatement: (node) ->
    node.left = @visit(node.left)
    node.right = @visit(node.right)
    node.body = @visit(node.body)
    return node

  ForOfStatement: (node) ->
    node.left = @visit(node.left)
    node.right = @visit(node.right)
    node.body = @visit(node.body)
    return node

  LetStatement: (node) ->
    node.head = @visit(node.head)
    node.body = @visit(node.body)
    return node

  DebuggerStatement: (node) -> node

  FunctionDeclaration: (node) ->
    node.id = @visit(node.id)
    node.params = @visit(node.params)
    node.defaults = @visit(node.defaults)
    node.rest = @visit(node.rest)
    node.body = @visit(node.body)
    return node

  VariableDeclaration: (node) ->
    node.declarations = @visit(node.declarations)
    return node

  VariableDeclarator: (node) ->
    node.id = @visit(node.id)
    node.init = @visit(node.init)
    return node

  ThisExpression: (node) -> node

  ArrayExpression: (node) ->
    node.elements = @visit(node.elements)
    return node

  ObjectExpression: (node) ->
    for property in node.properties
      property.value = @visit(property.value)
      property.key = @visit(property.key)
    return node

  FunctionExpression: (node) ->
    node.id = @visit(node.id)
    node.params = @visit(node.params)
    node.defaults = @visit(node.defaults)
    node.rest = @visit(node.rest)
    node.body = @visit(node.body)
    return node

  ArrowExpression: (node) ->
    node.params = @visit(node.params)
    node.defaults = @visit(node.defaults)
    node.rest = @visit(node.rest)
    node.body = @visit(node.body)
    return node

  SequenceExpression: (node) ->
    node.expressions = @visit(node.expressions)
    return node

  UnaryExpression: (node) ->
    node.argument = @visit(node.argument)
    return node

  BinaryExpression: (node) ->
    node.left = @visit(node.left)
    node.right = @visit(node.right)
    return node

  AssignmentExpression: (node) ->
    node.right = @visit(node.right)
    node.left = @visit(node.left)
    return node

  UpdateExpression: (node) ->
    node.argument = @visit(node.argument)
    return node

  LogicalExpression: (node) ->
    node.left = @visit(node.left)
    node.right = @visit(node.right)
    return node

  ConditionalExpression: (node) ->
    node.test = @visit(node.test)
    node.consequent = @visit(node.consequent)
    node.alternate = @visit(node.alternate)
    return node

  NewExpression: (node) ->
    node.callee = @visit(node.callee)
    node.arguments = @visit(node.arguments)
    return node

  CallExpression: (node) ->
    node.arguments = @visit(node.arguments)
    node.callee = @visit(node.callee)
    return node

  MemberExpression: (node) ->
    node.object = @visit(node.object)
    node.property = @visit(node.property)
    return node

  YieldExpression: (node) ->
    node.argument = @visit(node.argument)
    return node

  ComprehensionExpression: (node) ->
    node.body = @visit(node.body)
    node.blocks = @visit(node.blocks)
    node.filter = @visit(node.filter)
    return node

  GeneratorExpression: (node) ->
    node.body = @visit(node.body)
    node.blocks = @visit(node.blocks)
    node.filter = @visit(node.filter)
    return node

  LetExpression: (node) ->
    node.head = @visit(node.head)
    node.body = @visit(node.body)
    return node

  ObjectPattern: (node) ->
    for property in node.properties
      property.value = @visit(property.value)
      property.key = @visit(property.key)
    return node

  ArrayPattern: (node) ->
    node.elements = @visit(node.elements)
    return node

  SwitchCase: (node) ->
    node.test = @visit(node.test)
    node.consequent = @visit(node.consequent)
    return node

  CatchClause: (node) ->
    node.param = @visit(node.param)
    node.guard = @visit(node.guard)
    node.body = @visit(node.body)
    return node

  ComprehensionBlock: (node) ->
    node.left = @visit(node.pattern)
    node.right = @visit(node.right)
    return node

  Identifier: (node) -> node

  Literal: (node) -> node


module.exports = Visitor
