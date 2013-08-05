esprima = require 'esprima'

{Scope} = require './data'
Fiber = require './fiber'
compile = require './compiler'

class Vm
  constructor: (@maxDepth) ->
    @global = new Scope()

  eval: (string) ->
    ast = esprima.parse(string, loc: true)
    script = compile(ast)
    fiber = new Fiber(@maxDepth, @global, script)
    fiber.run()
    return fiber.stack.load()

module.exports = Vm
