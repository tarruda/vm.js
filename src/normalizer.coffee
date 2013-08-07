{parse} = require 'esprima'

AstVisitor = require './ast_visitor'

# Visitor that performs normalization of ast nodes that can be expressed as
# special cases or combination of other nodes
#
# The motivation of this visitor is to keep the Emitter implementation as
# simple as possible by only having to deal with a simplified AST
class Normalizer extends AstVisitor

  # Function normalization
  FunctionDeclaration: (node) ->
    node = @FunctionExpression(node)
    node.isExpression = false
    node.declare = node.id.name
    return node

  FunctionExpression: (node) ->
    node =
      loc: node.loc
      type: 'VmFunction'
      id: node.id
      params: node.params
      defaults: node.defaults
      rest: node.rest
      generator: node.generator
      expression: node.expression
      body: @visit(node.body)
      declare: false
      isExpression: true
    len = node.params.length
    if node.rest
      # initialize rest parameter
      rest = {type: 'VmRestParam', name: node.rest.name, index: len}
      node.body.body.unshift(rest)
    params = []
    for i in [0...len]
      param = node.params[i]
      def = node.defaults[i]
      declaration = parse("var placeholder = arguments[#{i}] || 0;").body[0]
      declarator = declaration.declarations[0]
      declarator.id = param
      if def then declarator.init.right = def
      else declarator.init = declarator.init.left
      params.push(@visit(declaration))
    node.body.body = params.concat(node.body.body)
    return node

  WhileStatement: (node) ->
    node = super(node)
    vmLoop =
      type: 'VmLoop'
      beforeTest: node.test
      body: node.body
    return vmLoop

  DoWhileStatement: (node) ->
    node = super(node)
    vmLoop =
      type: 'VmLoop'
      afterTest: node.test
      body: node.body
    return vmLoop

  ForStatement: (node) ->
    node = super(node)
    vmLoop =
      type: 'VmLoop'
      init: node.init
      update: node.update
      beforeTest: node.test
      body: node.body
    return vmLoop

  ForOfStatement: (node) ->
    # A for/of statement
    throw new Error('not implemented')

module.exports = Normalizer
