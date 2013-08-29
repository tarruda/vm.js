{VmError} = require './errors'


class StopIteration extends VmError
  @display: 'StopIteration'

  constructor: (@value, @message = 'iterator has stopped') ->


class ArrayIterator
  constructor: (@elements) ->
    @index = 0

  next: ->
    if @index >= @elements.length
      throw new StopIteration()
    return @elements[@index++]


exports.StopIteration = StopIteration
exports.ArrayIterator = ArrayIterator
