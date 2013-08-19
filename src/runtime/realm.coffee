{
  VmError, VmEvalError, VmRangeError, VmReferenceError, VmSyntaxError,
  VmTypeError, VmURIError
} = require './errors'
{NativeProxy, nativeBuiltins} = require './native'
{VmObject} = require './internal'
{ArrayIterator, StopIteration} = require './util'


hasProp = Object.prototype.hasOwnProperty

class Realm
  constructor: (merge) ->
    global = {
      undefined: undefined
      Object: Object
      Number: Number
      Boolean: Boolean
      String: String
      Array: Array
      Date: Date
      RegExp: RegExp
      Error: VmError
      EvalError: VmEvalError
      RangeError: VmRangeError
      ReferenceError: VmReferenceError
      SyntaxError: VmSyntaxError
      TypeError: VmTypeError
      URIError: VmURIError
      StopIteration: StopIteration
      Math: Math
      JSON: JSON
    }

    # Populate native proxies
    nativeProxies = {}

    for builtin in nativeBuiltins
      if builtin
        id = builtin.__mdid__
        if id
          nativeProxies[id] = new NativeProxy {
            object: builtin
          }

    nativeProxies[Array.prototype.__mdid__].include = {
      iterator: -> new ArrayIterator(this)
    }

    nativePrototypes = {
      Number: nativeProxies[Number.prototype.__mdid__]
      String: nativeProxies[String.prototype.__mdid__]
      Boolean: nativeProxies[Boolean.prototype.__mdid__]
      Object: nativeProxies[Object.prototype.__mdid__]
      Array: nativeProxies[Array.prototype.__mdid__]
      Date: nativeProxies[Date.prototype.__mdid__]
      RegExp: nativeProxies[RegExp.prototype.__mdid__]
    }

    objectProto = nativePrototypes.Object

    @getNativePrototype = (obj) ->
      type = /\[object\s(\w+)]/.exec(Object.prototype.toString.call(obj))[1]
      return nativePrototypes[type]

    @get = (obj, key) ->
      if typeof obj == 'object'
        if obj instanceof VmObject
          return obj.get(key)
        else if hasProp.call(obj, '__mdid__')
          return nativeBuiltins[obj.__mdid__].get(key, obj)
        else if key of obj
          return obj[key]
      proto = @getNativePrototype(obj)
      return proto.get(key, obj)

    @set = (obj, key, val) ->
      if typeof obj == 'object'
        if obj instanceof VmObject
          obj.set(key, val)
        else if hasProp.call(obj, '__mdid__')
          nativeBuiltins[id].set(key, val)
        else
          obj[key] = val
      return val

    @del = (obj, key) ->
      if typeof obj == 'object'
        if obj instanceof VmObject
          obj.del(key)
        else if hasProp.call(obj, '__mdid__')
          nativeBuiltins[id].del(key)
        else
          delete obj[key]
      return true

    for own k, v of merge
      global[k] = v

    @global = global


module.exports = Realm
