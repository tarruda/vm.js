AstVisitor = require './ast_visitor'

# Visitor that performs normalization of ast nodes that can be expressed as
# cases of other nodes(or combination of nodes).
#
# The motivation of this visitor is to keep the Emitter implementation as
# simple as possible by only having to deal with a simplified AST
class Normalizer extends AstVisitor

  # all function nodes are normalized to a simplified 'VmFunction' node
  FunctionDeclaration: (node) ->
    node = @FunctionExpression(node)
    node.push = false
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
      body: node.body
      declare: false
      push: true
    return node

module.exports = Normalizer
