Transformer = require '../ast/transformer'
Realm = require '../runtime/realm'
ConstantFolder = require '../ast/constant_folder'
Emitter = require './emitter'
{Fiber} = require './thread'


class Vm
  constructor: (merge) ->
    @realm = new Realm(merge)

  eval: (string, filename, timeout) ->
    @run(Vm.compile(string, filename), timeout)

  run: (script, timeout) ->
    fiber = @createFiber(script, timeout)
    evalStack = fiber.callStack[0].evalStack
    fiber.run()
    if not fiber.paused
      return evalStack.rexp

  createFiber: (script, timeout) ->
    fiber = new Fiber(@realm, timeout)
    fiber.pushFrame(script, @realm.global)
    return fiber

  @compile: (code, filename = '<script>') ->
    emitter = new Emitter(null, filename)
    transformer = new Transformer(new ConstantFolder(), emitter)
    transformer.transform(esprima.parse(code, {loc: true}))
    return emitter.end()


module.exports = Vm
