AstVisitor = require './ast_visitor'

# # visitor that performs normalization of ast nodes that represent
# # "syntatic sugar" so the Emitter implementation simpler
# class Normalizer extends AstVisitor

#   # a function declarations is a function expression that is bound
#   # at the beginning of the scope
#   FunctionDeclaration: (node) ->
#     expr =
#       loc: node.loc
#       type: 'FunctionExpression'
#       id: node.id
#       params: node.params
#       defaults: node.defaults
#       rest: node.rest
#       generator: node.generator
#       expression: node.expression
#       body: node.body
#     return {type: 'FunctionDeclaration'}
