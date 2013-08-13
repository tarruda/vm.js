{StopIteration} = require '../builtins/errors'


class IndexIterator
  constructor: (@elements) ->
    @index = 0

  next: ->
    if @index >= @elements.length
      throw StopIteration
    return @elements[@index++]


class PropertiesIterator extends IndexIterator
  constructor: (obj) ->
    properties = []
    for prop of obj
      properties.push(prop)
    super(properties)


exports.IndexIterator = IndexIterator
exports.PropertiesIterator = PropertiesIterator
