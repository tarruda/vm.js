esprima = require 'esprima'

Scope = require './scope'
Fiber = require './fiber'
compile = require './opcode_compiler'

class Vm
  constructor: (@maxDepth) ->
    @global = new Scope()

  eval: (string) ->
    ast = esprima.parse(string)
    script = compile(ast)
    fiber = new Fiber(@maxDepth, @global, script)
    fiber.run()
    return fiber.stack.load()


module.exports = Vm
