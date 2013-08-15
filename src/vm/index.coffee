Transformer = require '../ast/transformer'
Realm = require '../runtime/realm'
ConstantFolder = require '../ast/constant_folder'
Emitter = require './emitter'
{Fiber} = require './thread'


class Vm
  constructor: (@maxDepth, merge) ->
    @context = new Realm(merge)

  eval: (string) -> @run(@compile(string))

  compile: (source, filename = '<script>') -> compile(source, filename)

  run: (compiled) ->
    fiber = new Fiber(@context, @maxDepth, compiled)
    fiber.run()
    return fiber.evalStack.rexp


compile = (code) ->
  emitter = new Emitter()
  transformer = new Transformer(new ConstantFolder(), emitter)
  transformer.transform(esprima.parse(code, loc: false))
  return emitter.end()


module.exports = Vm
