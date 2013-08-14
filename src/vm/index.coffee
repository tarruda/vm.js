Transformer = require '../ast/transformer'
Context = require '../runtime/context'
ConstantFolder = require '../ast/constant_folder'
Emitter = require './emitter'
{Fiber} = require './thread'


class Vm
  constructor: (@maxDepth, merge) ->
    @context = new Context(merge)

  eval: (string) -> @run(@compile(string))

  compile: (source) -> compile(source)

  run: (compiled) ->
    fiber = new Fiber(@context, @global, @maxDepth, compiled)
    fiber.run()
    return fiber.evalStack.rexp


compile = (code) ->
  emitter = new Emitter()
  transformer = new Transformer(new ConstantFolder(), emitter)
  transformer.transform(esprima.parse(code, loc: false))
  return emitter.end()


module.exports = Vm
