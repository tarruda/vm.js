{VmError} = require './errors'


class ArrayIterator
  constructor: (@elements) ->
    @index = 0

  next: ->
    if @index >= @elements.length
      throw StopIteration
    return @elements[@index++]


StopIteration = new VmError()


# thanks john resig: http://ejohn.org/blog/objectgetprototypeof/
if typeof Object.getPrototypeOf != 'function'
  if typeof ''.__proto__ == 'object'
    prototypeOf = (obj) -> obj.__proto__
  else
    prototypeOf = (obj) -> obj.constructor.prototype
else
  prototypeOf = Object.getPrototypeOf

if typeof Object.create != 'function'
  create = ( ->
    F = ->
    return (o) ->
      if arguments.length != 1
        throw new Error(
          'Object.create implementation only accepts one parameter.')
      F.prototype = o
      return new F()
  )()
else
  create = Object.create


exports.ArrayIterator = ArrayIterator
exports.StopIteration = StopIteration
exports.prototypeOf = prototypeOf
exports.create = create
