{Scope} = require './data'
Fiber = require './fiber'
compile = require './compiler'

class Vm
  constructor: (@maxDepth) ->
    @global = new Scope()

  eval: (string) ->
    script = compile(string)
    fiber = new Fiber(@maxDepth, @global, script)
    fiber.run()
    return fiber.stack.load('_lastExpression')

module.exports = Vm
