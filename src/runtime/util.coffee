{VmError} = require './errors'


class ArrayIterator
  constructor: (@elements) ->
    @index = 0

  next: ->
    if @index >= @elements.length
      throw StopIteration
    return @elements[@index++]


StopIteration = new VmError()


exports.ArrayIterator = ArrayIterator
exports.StopIteration = StopIteration
