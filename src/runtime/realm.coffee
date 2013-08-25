{
  VmError, VmEvalError, VmRangeError, VmReferenceError, VmSyntaxError,
  VmTypeError, VmURIError
} = require './errors'
{
  ObjectMetadata, CowObjectMetadata, RestrictedObjectMetadata
} = require './metadata'
{isArray, prototypeOf, create, hasProp} = require './util'
RegExpProxy = require './regexp_proxy'


{ArrayIterator, StopIteration} = require './builtin'


runtimeProperties = {
  '__mdid__': null
  '__md__': null
  '__vmfunction__': null
  '__fiber__': null
  '__callname__': null
  '__construct__': null
  '__name__': null
}

class Realm
  constructor: (merge) ->
    global = {
      undefined: undef
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
      parseInt: parseInt
      parseFloat: parseFloat
    }

    global.global = global

    # Populate native proxies
    nativeMetadata = {}

    currentId = 0

    hasOwnProperty = (obj, key) ->
      mdid = obj.__mdid__
      md = nativeMetadata[obj.__mdid__]
      if md.object == obj or typeof obj not in ['object', 'function']
        # registered native object, or primitive type. use its corresponding
        # metadata object to read the property
        return md.hasOwnProperty(key, obj)
      if hasProp(obj, '__md__')
        return obj.__md__.hasOwnProperty(key)
      return hasProp(obj, key)

    register = (obj, restrict) =>
      if not hasProp(obj, '__mdid__')
        obj.__mdid__ = currentId + 1
      currentId = obj.__mdid__
      if obj.__mdid__ of nativeMetadata
        return
      type = typeof restrict
      if type == 'boolean' and type
        return nativeMetadata[obj.__mdid__] = new CowObjectMetadata(obj, this)
      if type == 'object'
        nativeMetadata[obj.__mdid__] = new RestrictedObjectMetadata(obj, this)
        if isArray(restrict)
          for k in restrict
            if hasProp(obj, k)
              nativeMetadata[obj.__mdid__].leak[k] = null
              register(obj[k], true)
        else
          for own k of restrict
            if hasProp(obj, k)
              nativeMetadata[obj.__mdid__].leak[k] = null
              register(obj[k], restrict[k])
        return
      return nativeMetadata[obj.__mdid__] = new ObjectMetadata(obj)

    register Object, {
      'prototype': [
        'toString'
      ]
    }

    register Function, {
      'prototype': [
        'apply'
        'call'
        'toString'
      ]
    }

    register Number, {
      'isNaN': true
      'isFinite': true
      'prototype': [
        'toExponential'
        'toFixed'
        'toLocaleString'
        'toPrecision'
        'toString'
        'valueOf'
      ]
    }

    register Boolean, {
      'prototype': [
        'toString'
        'valueOf'
      ]
    }

    register String, {
      'fromCharCode': true
      'prototype': [
        'charAt'
        'charCodeAt'
        'concat'
        'contains'
        'indexOf'
        'lastIndexOf'
        'replace'
        'search'
        'slice'
        'split'
        'substr'
        'substring'
        'toLowerCase'
        'toString'
        'toUpperCase'
        'valueOf'
      ]
    }

    register Array, {
      'isArray': true
      'every': true
      'prototype': [
        'join'
        'reverse'
        'sort'
        'push'
        'pop'
        'shift'
        'unshift'
        'splice'
        'concat'
        'slice'
        'indexOf'
        'lastIndexOf'
        'forEach'
        'map'
        'reduce'
        'reduceRight'
        'filter'
        'some'
        'every'
      ]
    }

    register Date, {
      'now': true
      'parse': true
      'UTC': true
      'prototype': [
        'getDate'
        'getDay'
        'getFullYear'
        'getHours'
        'getMilliseconds'
        'getMinutes'
        'getMonth'
        'getSeconds'
        'getTime'
        'getTimezoneOffset'
        'getUTCDate'
        'getUTCDay'
        'getUTCFullYear'
        'getUTCHours'
        'getUTCMilliseconds'
        'getUTCMinutes'
        'getUTCSeconds'
        'setDate'
        'setFullYear'
        'setHours'
        'setMilliseconds'
        'setMinutes'
        'setMonth'
        'setSeconds'
        'setUTCDate'
        'setUTCDay'
        'setUTCFullYear'
        'setUTCHours'
        'setUTCMilliseconds'
        'setUTCMinutes'
        'setUTCSeconds'
        'toDateString'
        'toISOString'
        'toJSON'
        'toLocaleDateString'
        'toLocaleString'
        'toLocaleTimeString'
        'toString'
        'toTimeString'
        'toUTCString'
        'valueOf'
      ]
    }

    register RegExp, {
      'prototype': [
        'exec'
        'test'
        'toString'
      ]
    }

    register Math, [
      'abs'
      'acos'
      'asin'
      'atan'
      'atan2'
      'ceil'
      'cos'
      'exp'
      'floor'
      'imul'
      'log'
      'max'
      'min'
      'pow'
      'random'
      'round'
      'sin'
      'sqrt'
      'tan'
    ]

    register JSON, [
      'parse'
      'stringify'
    ]

    register(parseFloat)

    register(parseInt)

    register(ArrayIterator, ['prototype'])

    register(RegExpProxy, ['prototype'])
   
    nativeMetadata[Object.__mdid__].properties = {
      create: create
    }

    nativeMetadata[Object.prototype.__mdid__].properties = {
      hasOwnProperty: (key) -> hasOwnProperty(this, key)
    }

    nativeMetadata[Array.prototype.__mdid__].properties = {
      iterator: -> new ArrayIterator(this)
    }

    nativeMetadata[String.prototype.__mdid__].properties = {
      match: (obj) ->
        if obj instanceof RegExpProxy
          return @match(obj.regexp)
        return @match(obj)
    }

    @mdproto = (obj) ->
      proto = prototypeOf(obj)
      if proto
        return nativeMetadata[proto.__mdid__]

    @has = (obj, key) ->
      if hasProp(runtimeProperties, key)
        return undef
      mdid = obj.__mdid__
      md = nativeMetadata[obj.__mdid__]
      if md.object == obj or typeof obj not in ['object', 'function']
        # registered native object, or primitive type. use its corresponding
        # metadata object to read the property
        return md.has(key, obj)
      if hasProp(obj, '__md__')
        return obj.__md__.has(key)
      if hasProp(obj, key)
        return true
      return @has(prototypeOf(obj), key)

    @get = (obj, key) ->
      if typeof obj == 'string' and typeof key == 'number' or key == 'length'
        # char at index or string length
        return obj[key]
      if hasProp(runtimeProperties, key)
        return undef
      mdid = obj.__mdid__
      md = nativeMetadata[obj.__mdid__]
      if md.object == obj or typeof obj not in ['object', 'function']
        # registered native object, or primitive type. use its corresponding
        # metadata object to read the property
        return md.get(key, obj)
      if hasProp(obj, '__md__')
        # use the inline metadata object to read the property
        return obj.__md__.get(key)
      if hasProp(obj, key)
        # read the property directly
        return obj[key]
      # search the object prototype chain
      return @get(prototypeOf(obj), key)

    @set = (obj, key, val) ->
      if hasProp(runtimeProperties, key)
        return undef
      if typeof obj in ['object', 'function']
        if hasProp(obj, '__md__')
          obj.__md__.set(key, val)
        else if hasProp(obj, '__mdid__')
          nativeMetadata[obj.__mdid__].set(key, val)
        else
          obj[key] = val
      return val

    @del = (obj, key) ->
      if hasProp(runtimeProperties, key)
        return undef
      type = typeof obj
      if type in ['object', 'function']
        if type == 'function' and key == 'prototype'
          # never allow a function prototype to be deleted
          return false
        if hasProp(obj, '__md__')
          obj.__md__.del(key)
        else if hasProp(obj, '__mdid__')
          nativeMetadata[obj.__mdid__].del(key)
        else
          delete obj[key]
      return true

    @instanceOf = (obj, klass) ->
      if typeof obj not in ['object', 'function']
        return false
      if hasProp(obj, '__md__')
        return obj.__md__.instanceOf(klass)
      if hasProp(obj, '__mdid__')
        return nativeMetadata[obj.__mdid__].instanceOf(klass)
      return obj instanceof klass

    @getNativeMetadata = (obj) ->
      return nativeMetadata[obj.__mdid__]

    @enumerateKeys = (obj) ->
      if typeof obj == 'object'
        if hasProp(obj, '__md__')
          return obj.__md__.enumerateKeys()
      keys = []
      for key of obj
        if key != '__mdid__'
          keys.push(key)
      return new ArrayIterator(keys)

    for own k, v of merge
      global[k] = v

    @global = global

    @registerNative = register

        

module.exports = Realm
