{
  VmError, VmEvalError, VmRangeError, VmReferenceError, VmSyntaxError,
  VmTypeError, VmURIError, StopIteration
} = require './errors'


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


# Creates a global object for a new vm instance
createGlobal = (merge) ->
  rv = {}

  objectProto = new NativeProxy {
    object: Object.prototype
    include:
      __proto__: null
  }

  numberProto = new NativeProxy {
    object: Number.prototype
    include:
      __proto__: objectProto
  }

  booleanProto = new NativeProxy {
    object: Boolean.prototype
    include:
      __proto__: objectProto
  }

  stringProto = new NativeProxy {
    object: String.prototype
    include:
      __proto__: objectProto
  }

  arrayProto = new NativeProxy {
    object: Array.prototype
    include:
      __proto__: objectProto
      iterator: -> new IndexIterator(this)
  }

  dateProto = new NativeProxy {
    object: Date.prototype
    include:
      __proto__: objectProto
  }

  regExpProto = new NativeProxy {
    object: RegExp.prototype
    include:
      __proto__: objectProto
  }

  errorProto = {__proto__: objectProto}

  evalErrorProto = {__proto__: errorProto}

  rangeErrorProto = {__proto__: errorProto}

  referenceErrorProto = {__proto__: errorProto}

  syntaxErrorProto = {__proto__: errorProto}

  typeErrorProto = {__proto__: errorProto}

  uriErrorProto = {__proto__: errorProto}

  rv.Math = new NativeProxy {
    object: Math
    include:
      __proto__: objectProto
  }

  rv.JSON = new NativeProxy {
    object: JSON
    include:
      __proto__: objectProto
  }

  rv.Object = new NativeProxy {
    object: Object
    include:
      prototype: objectProto

      getPrototypeOf: (obj) ->
        type = typeof obj
        switch type
          when 'number'
            return numberProto
          when 'boolean'
            return booleanProto
          when 'string'
            return stringProto
          when 'object'
            if obj instanceof Array
              return arrayProto
        return objectProto
  }

  rv.Number = new NativeProxy {
    object: Number
    include:
      prototype: numberProto
  }

  rv.Boolean = new NativeProxy {
    object: Boolean
    include:
      prototype: booleanProto
  }

  rv.String = new NativeProxy {
    object: String
    include:
      prototype: stringProto
  }

  rv.Array = new NativeProxy {
    object: Array
    include:
      prototype: arrayProto
  }

  rv.Date = new NativeProxy {
    object: Date
    include:
      prototype: dateProto
  }

  rv.RegExp = new NativeProxy {
    object: RegExp
    include:
      prototype: regExpProto
  }

  rv.Error = new NativeProxy {
    object: VmError
    include:
      prototype: errorProto
  }

  rv.EvalError = new NativeProxy {
    object: VmEvalError
    include:
      prototype: evalErrorProto
  }

  rv.RangeError = new NativeProxy {
    object: VmRangeError
    include:
      prototype: rangeErrorProto
  }

  rv.ReferenceError = new NativeProxy {
    object: VmReferenceError
    include:
      prototype: referenceErrorProto
  }

  rv.SyntaxError = new NativeProxy {
    object: VmSyntaxError
    include:
      prototype: syntaxErrorProto
  }

  rv.TypeError = new NativeProxy {
    object: VmTypeError
    include:
      prototype: typeErrorProto
  }

  rv.URIError = new NativeProxy {
    object: VmURIError
    include:
      prototype: uriErrorProto
  }

  for own k, v of merge
    if k not of rv
      rv[k] = v

  return rv


exports.createGlobal = createGlobal
exports.IndexIterator = IndexIterator
exports.PropertiesIterator = PropertiesIterator
exports.NativeProxy = NativeProxy
