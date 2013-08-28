{
  VmError, VmEvalError, VmRangeError, VmReferenceError, VmSyntaxError,
  VmTypeError, VmURIError
} = require './errors'
{
  ObjectMetadata, CowObjectMetadata, RestrictedObjectMetadata
  DataPropertyMetadata
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
  '__source__': null
  '__name__': null
}

class Realm
  constructor: (merge) ->
    global = {
      undefined: undef
      Object: Object
      Function: Function
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
      type = typeof obj
      objType = type in ['object', 'function']
      if hasProp(runtimeProperties, key)
        if objType
          if hasProp(obj, '__mdid__')
            md = nativeMetadata[obj.__mdid__]
          else if hasProp(obj, '__md__')
            md = obj.__md__
          if md
            return md.hasDefProperty(key)
        return false
      mdid = obj.__mdid__
      md = nativeMetadata[obj.__mdid__]
      if md and md.object == obj or not objType
        return md.hasOwnProperty(key, obj)
      if hasProp(obj, '__md__')
        return obj.__md__.hasOwnProperty(key)
      return hasProp(obj, key)

    register = (obj, restrict) =>
      if not hasProp(obj, '__mdid__')
        obj.__mdid__ = currentId + 1
      currentId = Math.max(obj.__mdid__, currentId)
      if hasProp(nativeMetadata, obj.__mdid__)
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
        'constructor'
        'toString'
      ]
    }

    register Function, {
      'prototype': [
        'constructor'
        'apply'
        'call'
        'toString'
      ]
    }

    register Number, {
      'isNaN': true
      'isFinite': true
      'prototype': [
        'constructor'
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
        'constructor'
        'toString'
        'valueOf'
      ]
    }

    register String, {
      'fromCharCode': true
      'prototype': [
        'constructor'
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
        'constructor'
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
        'constructor'
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
        'constructor'
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

    register(parseFloat, true)

    register(parseInt, true)

    register(ArrayIterator, ['prototype'])

    register(RegExpProxy, ['prototype'])
   
    nativeMetadata[Object.__mdid__].properties = {
      create: create
      getPrototypeOf: prototypeOf
    }

    nativeMetadata[Object.prototype.__mdid__].properties = {
      hasOwnProperty: (key) -> hasOwnProperty(this, key)
    }

    nativeMetadata[Function.prototype.__mdid__].properties = {
      toString: ->
        if @__source__
          return @__source__
        return @toString()
    }

    nativeMetadata[Array.prototype.__mdid__].properties = {
      iterator: -> new ArrayIterator(this)
    }

    nativeMetadata[String.prototype.__mdid__].properties = {
      match: (obj) ->
        if obj instanceof RegExpProxy
          return @match(obj.regexp)
        return @match(obj)
      replace: (obj) ->
        args = Array.prototype.slice.call(arguments)
        if obj instanceof RegExpProxy
          args[0] = obj.regexp
        return @replace.apply(this, args)
    }

    nativeMetadata[RegExp.prototype.__mdid__].properties = {
      exec: (str) ->
        if this instanceof RegExpProxy
          @regexp.lastIndex = @lastIndex
          rv = @regexp.exec(str)
          @lastIndex = @regexp.lastIndex
          return rv
        return @exec(str)

      test: (str) ->
        if this instanceof RegExpProxy
          @regexp.lastIndex = @lastIndex
          rv = @regexp.test(str)
          @lastIndex = @regexp.lastIndex
          return rv
        return @test(str)

      toString: ->
        if this instanceof RegExpProxy
          return @regexp.toString()
        return @toString()
    }

    @mdproto = (obj) ->
      proto = prototypeOf(obj)
      if proto
        return nativeMetadata[proto.__mdid__]

    @has = (obj, key) ->
      if not obj?
        return false
      type = typeof obj
      objType = type in ['object', 'function']
      if hasProp(runtimeProperties, key)
        if objType
          if hasProp(obj, '__mdid__')
            md = nativeMetadata[obj.__mdid__]
          else if hasProp(obj, '__md__')
            md = obj.__md__
          if md
            return md.hasDefProperty(key)
          return @has(prototypeOf(obj), key)
        return false
      mdid = obj.__mdid__
      md = nativeMetadata[obj.__mdid__]
      if md and md.object == obj or not objType
        return md.has(key, obj)
      if hasProp(obj, '__md__')
        return obj.__md__.has(key)
      if hasProp(obj, key)
        return true
      return @has(prototypeOf(obj), key)

    @get = (obj, key) ->
      if not obj?
        return undef
      type = typeof obj
      objType = type in ['object', 'function']
      if hasProp(runtimeProperties, key)
        if objType
          if hasProp(obj, '__mdid__')
            md = nativeMetadata[obj.__mdid__]
          else if hasProp(obj, '__md__')
            md = obj.__md__
          if md and md.hasDefProperty(key)
            return md.get(key)
          return @get(prototypeOf(obj), key)
        else
          # primitive
          return nativeMetadata[obj.__mdid__].get(key)
        return undef
      if type == 'string' and typeof key == 'number' or key == 'length'
        # char at index or string length
        return obj[key]
      mdid = obj.__mdid__
      md = nativeMetadata[obj.__mdid__]
      if md and md.object == obj or not objType
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
      type = typeof obj
      objType = type in ['object', 'function']
      if hasProp(runtimeProperties, key)
        # one of the special runtime properties. needs to be handled
        # separately
        if objType
          if hasProp(obj, '__mdid__')
            # nativeMetadata already uses copy-on-write, so no need to
            # define a special property
            nativeMetadata[obj.__mdid__].set(key, val)
          else
            if not hasProp(obj, '__md__')
              obj.__md__ = new ObjectMetadata(obj, this)
            md = obj.__md__
            if not md.hasDefProperty(key)
              prop = new DataPropertyMetadata(val, true, true, true)
              md.defineProperty(key, prop)
            md.set(key, val)
        return val
      if hasProp(runtimeProperties, key)
        return undef
      if objType
        if hasProp(obj, '__md__')
          obj.__md__.set(key, val)
        else if hasProp(obj, '__mdid__')
          nativeMetadata[obj.__mdid__].set(key, val)
        else
          obj[key] = val
      return val

    @del = (obj, key) ->
      type = typeof obj
      objType = type in ['object', 'function']
      if hasProp(runtimeProperties, key)
        if objType
          if hasProp(obj, '__mdid__')
            nativeMetadata[obj.__mdid__].del(key)
          else if hasProp(obj, '__md__')
            obj.__md__.delDefProperty(key)
        return true
      if objType
        if type == 'function' and key == 'prototype'
          # a function prototype cannot be deleted
          return false
        if hasProp(obj, '__md__')
          obj.__md__.del(key)
        else if hasProp(obj, '__mdid__')
          nativeMetadata[obj.__mdid__].del(key)
        else
          delete obj[key]
      return true

    @instanceOf = (klass, obj) ->
      if not obj? or typeof obj not in ['object', 'function']
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

  inv: (o) -> -o
  lnot: (o) -> not o
  not: (o) -> ~o
  inc: (o) -> o + 1
  dec: (o) -> o - 1

  add: (r, l) -> l + r
  sub: (r, l) -> l - r
  mul: (r, l) -> l * r
  div: (r, l) -> l / r
  mod: (r, l) -> l % r
  shl: (r, l) -> l << r
  sar: (r, l) -> l >> r
  shr: (r, l) -> l >>> r
  or: (r, l) -> l | r
  and: (r, l) -> l & r
  xor: (r, l) -> l ^ r

  ceq: (r, l) -> `l == r`
  cneq: (r, l) -> `l != r`
  cid: (r, l) -> l == r
  cnid: (r, l) -> l != r
  lt: (r, l) -> l < r
  lte: (r, l) -> l <= r
  gt: (r, l) -> l > r
  gte: (r, l) -> l >= r
        

module.exports = Realm
