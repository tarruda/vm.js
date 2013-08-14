Visitor = require './visitor'


class Transformer extends Visitor
  constructor: (@visitors...) ->

  visit: (node) ->
    for visitor in @visitors
      node = visitor.visit(node)

module.exports = Transformer
