{Closure, Scope} = require './data'


class Fiber
  constructor: (maxDepth, global, script) ->
    @stack = new OperandStack(64)
    @frames = new Array(maxDepth)
    @frames[0] = new Frame(this, @stack, script, global)
    @depth = 0

  run: ->
    while @depth >= 0 && !@frames[@depth].paused
      frame = @frames[@depth]
      frame.run()
    if !@depth && (remaining = @stack.remaining())
      # debug
      throw new Error("operand stack has #{remaining} items after execution")

  pushFrame: (closure) ->
    if @depth == @maxDepth - 1
      throw new Error('maximum call stack size exceeded')
    scope = new Scope(closure.parent, closure.script.vars)
    @frames[++@depth] = new Frame(this, @stack, closure.script, scope)

  popFrame: ->
    frame = @frames[--@depth]
    if frame
      frame.paused = false


class Frame
  constructor: (@fiber, @stack, @script, @scope) ->
    @ip = 0
    @paused = false

  run: ->
    instructions = @script.instructions
    len = instructions.length
    while @ip < len && !@paused
      instructions[@ip++].exec(this)
    if !@paused
      @fiber.popFrame()

  pop: -> @stack.pop()

  popn: (n) -> @stack.popn(n)

  top: -> @stack.top()

  push: (item) -> @stack.push(item)

  save: (name) -> @stack.save(name)

  load: (name) -> @stack.load(name)

  pull: (name) -> @stack.pull(name)

  get: (object, key) ->
    if object instanceof Scope then object.get(key)
    else object[key]

  set: (object, key, value) ->
    if object instanceof Scope then object.set(key, value)
    else object[key] = value
    @stack.push(value)

  jump: (to) -> @ip = to

  fn: (scriptIndex) ->
    @stack.push(new Closure(@script.scripts[scriptIndex], @scope))

  call: (length, closure) ->
    args = {length: length, callee: closure}
    while length
      args[--length] = @stack.pop()
    if closure instanceof Function
      # 'native' function, execute and push to the stack
      @stack.push(closure.apply(null, Array::slice.call(args)))
    else
      @stack.push(args)
      @paused = true
      @fiber.pushFrame(closure)

  restInit: (index, name) ->
    args = @scope.get('arguments')
    if index < args.length
      @scope.set(name, Array::slice.call(args, index))

  ret: -> @ip = @script.instructions.length


class OperandStack
  constructor: (size) ->
    @array = new Array(size)
    @idx = 0
    @tmp = {}

  save: (name) -> @tmp[name] = @pop()

  load: (name) -> @push(@tmp[name])

  pull: (name) ->
    value = @tmp[name]
    delete @tmp[name]
    @push(value)

  push: (item) -> @array[@idx++] = item

  pop: -> @array[--@idx]

  popn: (n) ->
    rv = []
    while n--
      rv.push(@array[--@idx])
    return rv

  top: -> @array[@idx - 1]

  remaining: -> @idx


module.exports = Fiber
