Transformer = require '../ast/transformer'
Realm = require '../runtime/realm'
ConstantFolder = require '../ast/constant_folder'
Emitter = require './emitter'
{Fiber} = require './thread'


class Vm
  constructor: (@maxDepth, merge) ->
    @realm = new Realm(merge)

  eval: (string, filename) -> @run(@compile(string, filename))

  compile: (source, filename = '<script>') -> compile(source, filename)

  run: (compiled) ->
    fiber = new Fiber(@realm, @maxDepth, compiled)
    fiber.run()
    return fiber.evalStack.rexp


compile = (code, filename) ->
  emitter = new Emitter(null, filename)
  transformer = new Transformer(new ConstantFolder(), emitter)
  transformer.transform(esprima.parse(code, loc: true))
  return emitter.end()


module.exports = Vm
