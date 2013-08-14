{StopIteration} = require './errors'

class ArrayIterator
  constructor: (@elements) ->
    @index = 0

  next: ->
    if @index >= @elements.length
      throw StopIteration
    return @elements[@index++]


exports.ArrayIterator = ArrayIterator
