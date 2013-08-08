{Scope} = require './data'
Fiber = require './fiber'
compile = require './compiler'

class Vm
  constructor: (@maxDepth) ->
    @global = {}

  eval: (string) -> @run(@compile(string))

  compile: (source) -> compile(source)

  run: (compiled) ->
    fiber = new Fiber(@global, @maxDepth, compiled)
    fiber.run()
    return fiber.evalStack.rexp

module.exports = Vm
