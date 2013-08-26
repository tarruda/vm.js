{VmError, VmTimeoutError} = require '../runtime/errors'


class Fiber
  constructor: (@realm, @timeout = -1) ->
    @maxDepth = 1000
    @maxTraceDepth = 50
    @callStack = []
    @evalStack = null
    @depth = -1
    @error = null
    @rv = undef
    @paused = false

  run: ->
    frame = @callStack[@depth]
    while @depth >= 0 and frame and not @paused
      if @error
        frame = @unwind()
      frame.run()
      if @error instanceof VmError
        @injectStackTrace(@error)
      if not frame.done()
        # possibly a function call, ensure 'frame' is pointing to the top
        frame = @callStack[@depth]
        continue
      # function returned, check if this was a constructor invocation
      # and act accordingly
      if frame.construct
        if typeof @rv not in ['object', 'function']
          @rv = frame.scope.get(0) # return this
      frame = @popFrame()
      if frame and not @error
        # set the return value
        frame.evalStack.push(@rv)
        @rv = undef
    if @timedOut()
      err = new VmTimeoutError(this)
      @injectStackTrace(err)
      throw err
    if @error
      throw @error

  unwind: ->
    # unwind the call stack searching for a guard set to handle this
    frame = @callStack[@depth]
    while frame
      # ip is always pointing to the next opcode, so subtract one
      ip = frame.ip - 1
      for guard in frame.script.guards
        if guard.start <= ip <= guard.end
          if guard.handler != null
            # try/catch
            if ip <= guard.handler
              # thrown inside the guarded region
              frame.evalStack.push(@error)
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

  injectStackTrace: (err) ->
    trace = []
    minDepth = 0
    if @depth > @maxTraceDepth
      minDepth = @depth - @maxTraceDepth
    for i in [@depth..minDepth]
      frame = @callStack[i]
      name = frame.script.name
      if name == '<anonymous>' and frame.fname
        name = frame.fname
      trace.push({
        at: {
          name: name
          filename: frame.script.filename
        }
        line: frame.line
        column: frame.column
      })
    if not err.trace
      err.trace = trace
    else
      err.trace.push(trace)
    # show stack trace on node.js
    err.stack = err.toString()

  pushFrame: (script, target, parent, args, name = '<anonymous>',
  construct = false) ->
    if not @checkCallStack()
      return
    scope = new Scope(parent, script.localNames, script.localLength)
    scope.set(0, target)
    frame = new Frame(this, script, scope, @realm, name, construct)
    if args
      frame.evalStack.push(args)
    @callStack[++@depth] = frame

  pushEvalFrame: (frame, script) ->
    if not @checkCallStack()
      return
    @callStack[++@depth] = new EvalFrame(frame, script)

  checkCallStack: ->
    if @depth is @maxDepth
      @error = new VmError('maximum call stack size exceeded')
      @pause()
      return false
    return true

  popFrame: ->
    frame = @callStack[--@depth]
    if frame
      frame.paused = false
    return frame

  setReturnValue: (rv) -> @callStack[@depth].evalStack.push(rv)

  pause: -> @paused = @callStack[@depth].paused = true

  resume: (@timeout = -1) ->
    @paused = false
    frame = @callStack[@depth]
    frame.paused = false
    evalStack = @callStack[0].evalStack
    @run()
    if not @paused
      return evalStack.rexp

  timedOut: -> @timeout == 0


class Frame
  constructor: (@fiber, @script, @scope, @realm, @fname, @construct = false) ->
    @evalStack = new EvaluationStack(@script.stackSize, @fiber)
    @ip = 0
    @exitIp = @script.instructions.length
    @paused = false
    @finalizer = null
    @rv = undef
    @line = @column = -1
    # frame-specific registers
    @r1 = @r2 = @r3 = @r4 = null

  run: ->
    instructions = @script.instructions
    while @ip != @exitIp and not @paused and @fiber.timeout != 0
      @fiber.timeout--
      instructions[@ip++].exec(this, @evalStack, @scope, @realm)
    if @fiber.timeout == 0
      @paused = @fiber.paused = true
    if not @paused and not @fiber.error and (len = @evalStack.len()) != 0
      # debug assertion
      throw new Error("Evaluation stack has #{len} items after execution")

  done: -> @ip is @exitIp

  # later we will use these methods to notify listeners(eg: debugger)
  # about line/column changes
  setLine: (@line) ->

  setColumn: (@column) ->


# Eval frame is like a normal frame, except it will use the current
# scope/guards
class EvalFrame extends Frame
  constructor: (frame, script) ->
    # copy try/catch guards to the script
    for guard in frame.script.guards
      script.guards.push(guard)
    super(frame.fiber, script, frame.scope, frame.realm, script.filename)

  run: ->
    super()
    # the eval function will return the expression evaluated last
    @fiber.rv = @evalStack.rexp

class EvaluationStack
  constructor: (size, @fiber) ->
    @array = new Array(size)
    @idx = 0
    @rexp = null

  push: (item) ->
    if @idx is @array.length
      throw new Error('maximum evaluation stack size exceeded')
    @array[@idx++] = item

  pop: -> @array[--@idx]

  top: -> @array[@idx - 1]

  len: -> @idx

  clear: -> @idx = 0


class Scope
  constructor: (@parent, @names, len) ->
    @data = new Array(len)

  get: (i) -> @data[i]

  set: (i, value) -> @data[i] = value

  name: (name) ->
    for own k, v of @names
      if v == name
        return parseInt(k)
    return -1

  namesHash: ->
    rv = {}
    for own k, v of @names
      if typeof v == 'string'
        rv[v] = parseInt(k)
    rv['this'] = 0
    rv['arguments'] = 1
    return rv


class WithScope
  constructor: (@parent, @object) ->

  get: (name) -> @object[name]

  set: (name, value) -> @object[name] = value

  has: (name) -> name of @object


exports.Fiber = Fiber
exports.Scope = Scope
exports.WithScope = WithScope
