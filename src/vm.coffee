compile = require './compiler'
{Fiber} = require './runtime'
{createGlobal, NativeProxy} = require './builtin/native'
{VmObject} = require './builtin/internal'
{ArrayIterator} = require './builtin/util'
{
  VmError, VmEvalError, VmRangeError, VmReferenceError, VmSyntaxError,
  VmTypeError, VmURIError, StopIteration
} = require './builtin/errors'


class Vm
  constructor: (@maxDepth, merge) ->
    global = {}

    objectProto = new NativeProxy {
      proto: null
      object: Object.prototype
    }

    numberProto = new NativeProxy {
      proto: objectProto
      object: Number.prototype
    }

    booleanProto = new NativeProxy {
      proto: objectProto
      object: Boolean.prototype
    }

    stringProto = new NativeProxy {
      proto: objectProto
      object: String.prototype
    }

    arrayProto = new NativeProxy {
      proto: objectProto
      object: Array.prototype
      include:
        iterator: -> new ArrayIterator(this)
    }

    dateProto = new NativeProxy {
      proto: objectProto
      object: Date.prototype
    }

    regExpProto = new NativeProxy {
      proto: objectProto
      object: RegExp.prototype
    }

    errorProto = new VmObject(objectProto, {})

    evalErrorProto = new VmObject(errorProto, {})

    rangeErrorProto = new VmObject(errorProto, {})

    referenceErrorProto = new VmObject(errorProto, {})

    syntaxErrorProto = new VmObject(errorProto, {})

    typeErrorProto = new VmObject(errorProto, {})

    uriErrorProto = new VmObject(errorProto, {})

    global.Math = new NativeProxy {
      proto: objectProto
      object: Math
    }

    global.JSON = new NativeProxy {
      proto: objectProto
      object: JSON
    }

    global.Object = new NativeProxy {
      object: Object
      include:
        prototype: objectProto

        getPrototypeOf: (obj) ->
          if not obj?
            throw new Error('Object.prototypeOf called on non-object')
          switch typeof obj
            when 'number'
              return numberProto
            when 'boolean'
              return booleanProto
            when 'string'
              return stringProto
            else
              return obj.proto
    }

    global.Number = new NativeProxy {
      object: Number
      include:
        prototype: numberProto
    }

    global.Boolean = new NativeProxy {
      object: Boolean
      include:
        prototype: booleanProto
    }

    global.String = new NativeProxy {
      object: String
      include:
        prototype: stringProto
    }

    global.Array = new NativeProxy {
      object: Array
      include:
        prototype: arrayProto
    }

    global.Date = new NativeProxy {
      object: Date
      include:
        prototype: dateProto
    }

    global.RegExp = new NativeProxy {
      object: RegExp
      include:
        prototype: regExpProto
    }

    global.Error = new NativeProxy {
      object: VmError
      include:
        prototype: errorProto
    }

    global.EvalError = new NativeProxy {
      object: VmEvalError
      include:
        prototype: evalErrorProto
    }

    global.RangeError = new NativeProxy {
      object: VmRangeError
      include:
        prototype: rangeErrorProto
    }

    global.ReferenceError = new NativeProxy {
      object: VmReferenceError
      include:
        prototype: referenceErrorProto
    }

    global.SyntaxError = new NativeProxy {
      object: VmSyntaxError
      include:
        prototype: syntaxErrorProto
    }

    global.TypeError = new NativeProxy {
      object: VmTypeError
      include:
        prototype: typeErrorProto
    }

    global.URIError = new NativeProxy {
      object: VmURIError
      include:
        prototype: uriErrorProto
    }

    @createObject = (container) -> new VmObject(objectProto, container)

    @createArray = (container) -> new VmObject(arrayProto, container)

    @getPrimitivePrototype = (type) ->
      switch type
        when 'number'
          return numberProto
        when 'boolean'
          return booleanProto
        when 'string'
          return stringProto
        else
          throw new Error('assert error')

    for own k, v of merge
      global[k] = v

    @global = global

  eval: (string) -> @run(@compile(string))

  compile: (source) -> compile(source)

  run: (compiled) ->
    fiber = new Fiber(this, @global, @maxDepth, compiled)
    fiber.run()
    return fiber.evalStack.rexp


module.exports = Vm
