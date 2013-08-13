{StopIteration} = require './errors'


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


# This class has two basic features:
#
# - It lets sandboxed code to safely read/write builtin objects properties
#   from the host vm without touching the real object behind the proxy
# - It provides builtin objects with properties that are only visible
#   inside the vm(eg: 'iterator' on array prototype)
#
class NativeProxy
  constructor: (opts) ->
    @object = opts.object
    @include = opts.include or {}
    @exclude = opts.exclude or {}
    @modified = false

  get: (property) ->
    if property of @exclude
      return undefined
    return @include[property] or @object[property]

  set: (property, value) ->
    @include[property] = value
    @modified = true
    return value

  del: (property) ->
    @exclude[property] = null
    @modified = true

  toString: -> @object.toString()


exports.IndexIterator = IndexIterator
exports.PropertiesIterator = PropertiesIterator
exports.NativeProxy = NativeProxy
