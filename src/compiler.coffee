class Compiler
  constructor: (@visitors...) ->

  compile: (node) ->
    node = esprima.parse(node, loc: false)
    for visitor in @visitors
      node = visitor.visit(node)


module.exports = Compiler
