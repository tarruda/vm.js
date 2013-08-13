{Fiber} = require './runtime'
compile = require './compiler'
{createGlobal} = require './builtin/native'

class Vm
  constructor: (@maxDepth) ->
    @global = createGlobal({})

  eval: (string) -> @run(@compile(string))

  compile: (source) -> compile(source)

  run: (compiled) ->
    fiber = new Fiber(@global, @maxDepth, compiled)
    fiber.run()
    return fiber.evalStack.rexp


module.exports = Vm
