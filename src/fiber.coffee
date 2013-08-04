Scope = require '../src/scope'


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
    @frames[++@depth] = new Frame(this, @stack, closure.script, closure.parent)

  popFrame: ->
    frame = @frames[--@depth]
    if frame
      frame.paused = false


class Frame
  constructor: (@fiber, @stack, @script, parentScope) ->
    @scope = new Scope(parentScope, @script.vars)
    @ip = 0
    @paused = false

  run: ->
    instructions = @script.instructions
    len = instructions.length
    while @ip < len && !@paused
      instructions[@ip++].exec(this)
    if !@paused
      @fiber.popFrame()

  get: (object, key) ->
    if object instanceof Scope then object.get(key)
    else object[key]

  set: (object, key, value) ->
    if object instanceof Scope then object.set(key, value)
    else object[key] = value
    @stack.push(value)

  jump: (to) -> @ip = to

  pop: -> @stack.pop()

  popn: (n) -> @stack.popn(n)

  top: -> @stack.top()

  dup: -> @stack.dup()

  dup2: -> @stack.dup2()

  swap: -> @stack.swap()

  push: (item) -> @stack.push(item)

  save: -> @stack.save()

  save2: -> @stack.save2()

  load: -> @stack.load()

  load2: -> @stack.load2()

  pushScope: -> @stack.push(@scope)

  fn: (scriptIndex) ->
    @stack.push(new Closure(@script.scripts[scriptIndex], @scope))

  call: (closure) ->
    @paused = true
    @fiber.pushFrame(closure)

  ret: -> @ip = @script.instructions.length


class Closure
  constructor: (@script, @parent) ->

class OperandStack
  constructor: (size) ->
    @array = new Array(size)
    @idx = 0
    @slot1 = null
    @slot2 = null

  save: -> @slot1 = @pop()

  save2: -> @slot1 = @pop(); @slot2 = @pop()

  load: -> @push(@slot1)

  load2: -> @push(@slot2); @push(@slot1)

  dup: -> @push(@array[@idx - 1])

  dup2: -> @push(@array[@idx - 2]); @push(@array[@idx - 2])

  swap: -> top = @pop(); bot = @pop(); @push(top); @push(bot)

  push: (item) -> @array[@idx++] = item

  pop: -> @array[--@idx]

  popn: (n) ->
    rv = []
    while n--
      rv.push(@array[--@idx])
    return rv

  top: -> @array[@idx - 1]

  inspect: ->
    rv = []; i = @idx
    while i--
      rv.push((@array[i].inspect || @array[i].toString)())
    return rv.reverse().join(', ')

  remaining: -> @idx

module.exports = Fiber
