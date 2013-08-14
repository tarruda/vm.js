{VmFunction, VmObject} = require './builtin/internal'
{VmTypeError} = require './builtin/errors'


class Fiber
  constructor: (@vm, @global, maxDepth, script) ->
    @callStack = new Array(maxDepth)
    @callStack[0] = new Frame(this, script, null, global, vm)
    @evalStack = @callStack[0].evalStack
    @depth = 0
    @error = null
    @rv = undefined

  run: ->
    frame = @callStack[@depth]
    while @depth >= 0 and frame
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

  pushFrame: (func, args) ->
    if @depth is @maxDepth - 1
      throw new Error('maximum call stack size exceeded')
    scope = new Scope(func.parent, func.script.localNames,
      func.script.localLength)
    frame = new Frame(this, func.script, scope, @global, @vm)
    frame.evalStack.push(args)
    @callStack[++@depth] = frame

  popFrame: ->
    frame = @callStack[--@depth]
    if frame
      frame.paused = false
    return frame


class Frame
  constructor: (@fiber, @script, @scope, @global, @vm) ->
    @evalStack = new EvaluationStack(@script.stackSize)
    @ip = 0
    @exitIp = @script.instructions.length
    @paused = false
    @iterBreaks = []
    @finalizer = null
    @rv = undefined
    @r1 = @r2 = @r3 = @r4 = null

  enterScope: ->
    if not @scope
      # block inside global scope
      @scope = new Scope(null, @script.localNames, @script.localLength)

  exitScope: ->
    @scope = @scope.parent

  run: ->
    instructions = @script.instructions
    while @ip != @exitIp and not @paused
      instructions[@ip++].exec(this, @evalStack, @scope, @global, @vm)
    if (len = @evalStack.len()) != 0
      # debug assertion
      throw new Error("Evaluation stack has #{len} items after execution")

  iterPush: (to) -> @iterBreaks.push(to)

  iterPop: (to) -> @iterBreaks.pop()

  jump: (to) -> @ip = to

  fn: (scriptIndex) -> new VmFunction(@script.scripts[scriptIndex], @scope)

  debug: ->

  get: (obj, property) ->
    type = typeof obj
    switch type
      when 'number', 'boolean', 'string'
        proto = @global['*getPrimitivePrototype'](type)
        return proto.get(property, obj)
      when 'object'
        if obj instanceof VmObject
          return obj.get(property)
        return obj[property]
      else
        throw new Error('assert error')

  set: (obj, property, value) ->
    type = typeof obj
    switch type
      when 'number', 'boolean', 'string'
        proto = @global['*getPrimitivePrototype'](type)
        proto.set(property, value, obj)
      when 'object'
        if obj instanceof VmObject
          obj.set(property, value)
        obj[property] = value
      else
        throw new Error('assert error')
    return value

  del: (obj, property, value) ->
    type = typeof obj
    switch type
      when 'number', 'boolean', 'string'
        proto = @global['*getPrimitivePrototype'](type)
        return proto.del(property)
      when 'object'
        if obj instanceof VmObject
          return obj.del(property)
        delete obj[property]
      else
        throw new Error('assert error')

  invoke: (length, property, target) ->
    if target instanceof VmObject
      target.invoke(this, property, length)
    else
      @call(length, target[property], target)

  call: (length, func, target) ->
    if not (func instanceof VmFunction) and not (func instanceof Function)
      @fiber.error = new VmTypeError("Object #{func} is not a function")
      @paused = true
      return

    args = {length: length, callee: func}

    while length
      args[--length] = @evalStack.pop()

    if func instanceof Function
      # 'native' function, execute and push to the evaluation stack
      try
        @evalStack.push(func.apply(target, Array::slice.call(args)))
      catch nativeError
        @paused = true
        @fiber.error = nativeError
    else
      # TODO set context
      @paused = true
      @fiber.pushFrame(func, args)

  rest: (index, varIndex) ->
    args = @scope.get(0)
    if index < args.length
      @scope.set(varIndex, Array::slice.call(args, index))

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

  done: -> @ip is @exitIp


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


exports.Fiber = Fiber
