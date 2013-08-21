{VmError} = require '../runtime/errors'


class Fiber
  constructor: (@realm) ->
    @maxDepth = 256
    @callStack = new Array(@maxDepth)
    @evalStack = null
    @depth = -1
    @error = null
    @rv = undefined
    @paused = false

  run: ->
    frame = @callStack[@depth]
    while @depth >= 0 and frame and not @paused
      if @error
        frame = @unwind()
      frame.run()
      if not frame.done()
        frame = @callStack[@depth] # function call
        continue
      # function returned
      frame = @popFrame()
      if frame and not @error
        # set the return value
        frame.evalStack.push(@rv)
        @rv = undefined

  unwind: ->
    if @error instanceof VmError
      @injectStackTrace()
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

  injectStackTrace: ->
    trace = []
    for i in [@depth..0]
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
    @error.trace = trace

  pushFrame: (script, target, parent = null, args = null,
  name = '<anonymous>', isConstructor = false) ->
    if @depth is @maxDepth - 1
      throw new Error('maximum call stack size exceeded')
    scope = new Scope(parent, script.localNames, script.localLength)
    if isConstructor
      proto = @realm.get(func, 'prototype')
      newObj = {}
      if proto
        newObj.__md__ = {
          prototype: proto
        }
      target = newObj
    scope.set(0, target)
    frame = new Frame(this, script, scope, @realm, name)
    if args
      frame.evalStack.push(args)
    @callStack[++@depth] = frame

  popFrame: ->
    frame = @callStack[--@depth]
    if frame
      frame.paused = false
    return frame

  setReturnValue: (rv) -> @callStack[@depth].evalStack.push(rv)

  pause: -> @paused = @callStack[@depth].paused = true

  resume: ->
    @paused = false
    frame = @callStack[@depth]
    frame.paused = false
    evalStack = @callStack[0].evalStack
    @run()
    if not @paused
      return evalStack.rexp


class Frame
  constructor: (@fiber, @script, @scope, @realm, @fname) ->
    @evalStack = new EvaluationStack(@script.stackSize)
    @ip = 0
    @exitIp = @script.instructions.length
    @paused = false
    @finalizer = null
    @rv = undefined
    @line = @column = -1
    # frame-specific registers
    @r1 = @r2 = @r3 = @r4 = null

  run: ->
    instructions = @script.instructions
    while @ip != @exitIp and not @paused
      instructions[@ip++].exec(this, @evalStack, @scope, @realm)
    if not @paused and not @fiber.error and (len = @evalStack.len()) != 0
      # debug assertion
      throw new Error("Evaluation stack has #{len} items after execution")

  done: -> @ip is @exitIp

  # later we will use these methods to notify listeners(eg: debugger)
  # about line/column changes
  setLine: (@line) ->

  setColumn: (@column) ->


class EvaluationStack
  constructor: (size) ->
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


class Scope
  constructor: (@parent, @names, len) ->
    @data = new Array(len)

  get: (i) -> @data[i]

  set: (i, value) -> @data[i] = value

  name: (name) ->
    for k, v of @names
      if v == name
        return parseInt(k)
    return - 1


class WithScope
  constructor: (@parent, @object) ->

  get: (name) -> @object[name]

  set: (name, value) -> @object[name] = value

  has: (name) -> name of @object


exports.Fiber = Fiber
exports.Scope = Scope
exports.WithScope = WithScope
