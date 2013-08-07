{Closure, Scope} = require './data'


class Fiber
  constructor: (maxDepth, global, script) ->
    @stack = new OperandStack(512)
    @frames = new Array(maxDepth)
    @frames[0] = new Frame(this, @stack, script, global)
    @depth = 0
    @error = null
    @rv = undefined

  run: ->
    frame = @frames[@depth]
    while @depth >= 0 && frame
      if @error
        frame = @unwind()
      frame.run()
      if !frame.done()
        frame = @frames[@depth] # function call
        continue
      # function returned
      @stack.push(@rv)
      @rv = undefined
      frame = @popFrame()
    if !@depth && ((remaining = @stack.remaining()) != 0)
      # debug
      throw new Error("operand stack has #{remaining} items after execution")

  unwind: ->
    # unwind the stack searching for a guard set to handle this
    frame = @frames[@depth]
    while frame
      # ip is always pointing to the next opcode, so subtract one
      ip = frame.ip - 1
      for guard in frame.script.guards
        if guard.start <= ip <= guard.end
          if guard.handler != null
            # try/catch
            if ip <= guard.handler
              # thrown inside the guarded region
              @error = null
              frame.ip = guard.handler
              if guard.finalizer != null
                # if the catch returns from the function, the finally
                # block still must be executed, so adjust the exitIp
                # to match the try/catch/finally block last ip.
                frame.exitIp = guard.end
                # warn the frame about finalization so the RET instruction
                # will correctly jump to it
                frame.finalizer = guard.finalizer
            else
              # thrown outside the guarded region(eg: catch or finally block)
              continue
          else
            # try/finally
            frame.ip = guard.finalizer
          frame.paused = false
          return frame
      frame = @popFrame()
    throw @error

  pushFrame: (closure) ->
    if @depth == @maxDepth - 1
      throw new Error('maximum call stack size exceeded')
    scope = new Scope(closure.parent, closure.script.vars)
    @frames[++@depth] = new Frame(this, @stack, closure.script, scope)

  popFrame: ->
    frame = @frames[--@depth]
    if frame
      frame.paused = false
    return frame

class Frame
  constructor: (@fiber, @stack, @script, @scope) ->
    @ip = 0
    @exitIp = @script.instructions.length
    @paused = false
    @finalizer = null
    @rv = undefined
    @r1 = @r2 = @r3 = @r4 = null

  run: ->
    instructions = @script.instructions
    while @ip != @exitIp && !@paused
      instructions[@ip++].exec(this, @stack)

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

  debug: ->

  call: (length, isMethod) ->
    closure = @stack.pop()
    args = {length: length, callee: closure}
    while length
      args[--length] = @stack.pop()
    if isMethod
      target = @stack.pop()
    if closure instanceof Function
      # 'native' function, execute and push to the stack
      try
        @stack.push(closure.apply(target, Array::slice.call(args)))
      catch e
        console.log "native function throws an error"
        throw e
    else
      # TODO set context
      @stack.push(args)
      @paused = true
      @fiber.pushFrame(closure)

  restInit: (index, name) ->
    args = @scope.get('arguments')
    if index < args.length
      @scope.set(name, Array::slice.call(args, index))

  ret: ->
    if @finalizer
      @ip = @finalizer
      @finalizer = null
    else
      @ip = @exitIp

  retv: (value) ->
    @fiber.rv = value
    @ret()

  throw: (obj) ->
    @paused = true
    @fiber.error = obj

  done: -> @ip == @exitIp


class OperandStack
  constructor: (size) ->
    @array = new Array(size)
    @idx = 0
    @rexp = null

  push: (item) -> @array[@idx++] = item

  pop: ->
    rv = @array[--@idx]
    @array[@idx] = null
    return rv

  top: -> @array[@idx - 1]

  remaining: -> @idx


module.exports = Fiber
