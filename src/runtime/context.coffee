{
  VmError, VmEvalError, VmRangeError, VmReferenceError, VmSyntaxError,
  VmTypeError, VmURIError
} = require './errors'
{NativeProxy, nativeBuiltins} = require './native'
{VmObject} = require './internal'
{ArrayIterator, StopIteration} = require './util'


# Execution context, global object + some helper methods
class Context
  constructor: (merge) ->
    global = {
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
        nativeProxies[builtin.vmjsNativeBuiltinId] = new NativeProxy {
          object: builtin
        }

    nativeProxies[Array.prototype.vmjsNativeBuiltinId].include = {
      iterator: -> new ArrayIterator(this)
    }

    nativePrototypes = {
      Number: nativeProxies[Number.prototype.vmjsNativeBuiltinId]
      String: nativeProxies[String.prototype.vmjsNativeBuiltinId]
      Boolean: nativeProxies[Boolean.prototype.vmjsNativeBuiltinId]
      Object: nativeProxies[Object.prototype.vmjsNativeBuiltinId]
      Array: nativeProxies[Array.prototype.vmjsNativeBuiltinId]
      Date: nativeProxies[Date.prototype.vmjsNativeBuiltinId]
      RegExp: nativeProxies[RegExp.prototype.vmjsNativeBuiltinId]
    }

    objectProto = nativePrototypes.Object

    @getNativePrototype = (obj) ->
      type = /\[object\s(\w+)]/.exec(Object.prototype.toString.call(obj))[1]
      return nativePrototypes[type]

    @get = (obj, key) ->
      if obj instanceof VmObject
        rv = obj.get(key)
      else if (id = obj.vmjsNativeBuiltinId)
        rv = nativeBuiltins[id].get(key, obj)
      else if key of obj
        rv = obj[key]
      else
        proto = @getNativePrototype(obj)
        rv = proto.get(key, obj)
      return rv

    @set = (obj, key, val) ->
      if obj instanceof VmObject
        obj.set(key, val)
      else if (id = obj.vmjsNativeBuiltinId)
        nativeBuiltins[id].set(key, val)
      else
        obj[key] = val
      return val

    @del = (obj, key) ->
      if obj instanceof VmObject
        obj.del(key)
      else if (id = obj.vmjsNativeBuiltinId)
        nativeBuiltins[id].del(key)
      else
        delete obj[key]
      return true

    for own k, v of merge
      global[k] = v

    @global = global


module.exports = Context
