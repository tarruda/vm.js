{Fiber} = require './runtime'
compile = require './compiler'
{NativeProxy, IndexIterator} = require './builtin/native'

class Vm
  constructor: (@maxDepth) ->
    @global = createGlobalObject({})

  eval: (string) -> @run(@compile(string))

  compile: (source) -> compile(source)

  run: (compiled) ->
    fiber = new Fiber(@global, @maxDepth, compiled)
    fiber.run()
    return fiber.evalStack.rexp


# global object unique per vm instance
createGlobalObject = (merge) ->
  rv = {}

  arrayPrototype = new NativeProxy {
    object: Array.prototype
    include:
      iterator: -> new IndexIterator(this)
  }

  rv.Array = new NativeProxy {
    object: Array
    include:
      prototype: arrayPrototype
  }

  for own k, v of merge
    if k not of rv
      rv[k] = v

  return rv

class GlobalObject

module.exports = Vm
