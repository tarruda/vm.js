{
  VmError, VmEvalError, VmRangeError, VmReferenceError, VmSyntaxError,
  VmTypeError, VmURIError
} = require './errors'
{
  ObjectMetadata, CowObjectMetadata, RestrictedObjectMetadata
} = require './metadata'

{ArrayIterator, StopIteration} = require './util'


hasProp = (obj, prop) -> Object.prototype.hasOwnProperty.call(obj, prop)

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
    nativeMetadata = {}

    currentId = 0

    @registerNative = register = (obj, restrict) ->
      if not hasProp(obj, '__mdid__')
        obj.__mdid__ = currentId + 1
      currentId = obj.__mdid__
      if obj.__mdid__ of nativeMetadata
        return
      type = typeof restrict
      if type == 'boolean' and type
        return nativeMetadata[obj.__mdid__] = new CowObjectMetadata(obj)
      if type == 'object'
        nativeMetadata[obj.__mdid__] = new RestrictedObjectMetadata(obj)
        if Array.isArray(restrict)
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

    register(Object, ['prototype'])

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
        'match'
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

    register(ArrayIterator, ['prototype'])
   
    nativeMetadata[Array.prototype.__mdid__].properties = {
      iterator: -> new ArrayIterator(this)
    }

    @get = (obj, key) ->
      mdid = obj.__mdid__
      md = nativeMetadata[obj.__mdid__]
      if typeof obj != 'object' or obj == md.object or not hasProp(obj, key)
        # primitive or native builtin or something that inherits from one
        return md.get(key, obj)
      # check for inline metadata object
      if hasProp(obj, '__md__')
        return obj.__md__.get(key)
      # delegate lookup to the host javascript vm
      return obj[key]

    @set = (obj, key, val) ->
      if typeof obj == 'object'
        if hasProp(obj, '__md__')
          obj.__md__.set(key, val)
        else if hasProp(obj, '__mdid__')
          nativeBuiltins[obj.__mdid__].set(key, val)
        else
          obj[key] = val
      return val

    @del = (obj, key) ->
      if typeof obj == 'object'
        if hasProp(obj, '__md__')
          obj.__md__.del(key)
        else if hasProp(obj, '__mdid__')
          nativeBuiltins[obj.__mdid__].del(key)
        else
          delete obj[key]
      return true

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


module.exports = Realm
