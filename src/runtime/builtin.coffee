{VmError} = require './errors'



StopIteration = new VmError()


class ArrayIterator
  constructor: (@elements) ->
    @index = 0

  next: ->
    if @index >= @elements.length
      throw StopIteration
    return @elements[@index++]


exports.StopIteration = StopIteration
exports.ArrayIterator = ArrayIterator
