{VmObject} = require './internal'
{ArrayIterator} = require './util'


# This class has two basic use cases:
#
# - It lets sandboxed code to safely read/write builtin objects properties
#   from the host vm without touching the real object behind the proxy
#   (simple copy-on-write properties)
# - It provides builtin objects with properties that are only visible
#   inside the vm(eg: 'iterator' on array prototype)
#
class NativeProxy extends VmObject
  constructor: (opts) ->
    super(opts.proto, opts.object)
    # included properties
    @include = opts.include or {}
    # excluded properties
    @exclude = opts.exclude or {}

  hasOwnProperty: (key) ->
    (key of @container and not key of @exclude) or key of @include

  getOwnProperty: (key) ->
    if key of @include
      return @include[key]
    if key of @container and key not of @exclude
      return @container[key]
    return undefined

  setOwnProperty: (key, value) ->
    if key of @exclude
      delete @exclude[key]
    if value != @container[key]
      @include[key] = value

  delOwnProperty: (key) ->
    if key of @include
      delete @include[key]
    @exclude[key] = null

  get: (key, target = @container) -> super(key, target)

  set: (key, value, target = @container) -> super(key, value, target)

  isEnumerable: (k, v) ->
    if k of @exclude
      return false
    return not (v instanceof VmProperty) or v.enumerable

  ownKeys: ->
    keys = super()
    for k of @include
      if k not in keys
        keys.push(k)
    return keys


exports.ArrayIterator = ArrayIterator
exports.NativeProxy = NativeProxy
