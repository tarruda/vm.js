{Scope} = require './data'
Fiber = require './fiber'
compile = require './compiler'

class Vm
  constructor: (@maxDepth) ->
    @global = {}

  eval: (string) ->
    script = compile(string)
    fiber = new Fiber(@global, @maxDepth, script)
    fiber.run()
    return fiber.evalStack.rexp

module.exports = Vm
