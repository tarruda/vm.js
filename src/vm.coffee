esprima = require 'esprima'

{Scope} = require './data'
Fiber = require './fiber'
Emitter = require './emitter'

class Vm
  constructor: (@maxDepth) ->
    @global = new Scope()

  eval: (string) ->
    ast = esprima.parse(string, loc: true)
    script = new Emitter().emit(ast).end()
    fiber = new Fiber(@maxDepth, @global, script)
    fiber.run()
    return fiber.stack.load()


module.exports = Vm
