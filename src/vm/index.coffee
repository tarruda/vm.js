Transformer = require '../ast/transformer'
Realm = require '../runtime/realm'
ConstantFolder = require '../ast/constant_folder'
Emitter = require './emitter'
{Fiber} = require './thread'
Script = require './script'


class Vm
  constructor: (merge) ->
    @realm = new Realm(merge)
    @realm.compileFunction = Vm.compileFunction

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

  @compile: (source, filename = '<script>') ->
    emitter = new Emitter(null, filename, null, source.split('\n'))
    return compile(source, emitter)

  @compileFunction: (args) ->
    functionArgs = []
    if args.length > 1
      for i in [0...args.length - 1]
        functionArgs = functionArgs.concat(args[i].split(','))
    body = args[args.length - 1]
    source =
      """
      (function(#{functionArgs.join(', ')}) {
      #{body}
      })
      """
    emitter = new Emitter([{this: 0, arguments: 1}], '<eval>', null,
      source.split('\n'))
    program = compile(source, emitter)
    return program.scripts[0]

  @fromJSON: Script.fromJSON

  @parse: esprima.parse


compile = (source, emitter) ->
  transformer = new Transformer(new ConstantFolder(), emitter)
  transformer.transform(esprima.parse(source, {loc: true}))
  return emitter.end()


module.exports = Vm
