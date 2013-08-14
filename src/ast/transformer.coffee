class Transformer
  constructor: (@visitors...) ->

  transform: (ast) ->
    for visitor in @visitors
      ast = visitor.visit(ast)
    return ast

module.exports = Transformer
