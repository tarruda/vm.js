esprima = require('esprima')

Visitor = require('../ast/visitor')
{StopIteration, ArrayIterator} = require('../runtime/builtin')
{defProp, hasProp, create} = require('../runtime/util')
{VmTypeError, VmEvalError, VmReferenceError} = require('../runtime/errors')
RegExpProxy = require('../runtime/regexp_proxy')
{Fiber, Scope, WithScope} = require('./thread')


OpcodeClassFactory = ( ->
  # opcode id, correspond to the index in the opcodes array and is used
  # to represent serialized opcodes
  id = 0

  classFactory = (name, fn, calculateFactor) ->
    # generate opcode class
    # this is ugly but its the only way I found to get nice opcode
    # names when debugging with node-inspector/chrome dev tools
    OpcodeClass = ( ->
      if typeof eval != 'function' or (typeof (
        constructor = eval(
          "(function #{name}(args) { if (args) this.args = args; })")) !=
            'function')
        constructor = (args) ->
          if args
            @args = args
          return # explicitly return undefined
        constructor.name = name
      constructor::id = id++
      constructor::name = name
      constructor::exec = fn
      if calculateFactor
        constructor::calculateFactor = calculateFactor
      else
        constructor::factor = calculateOpcodeFactor(fn)
        constructor::calculateFactor = -> @factor
      return constructor
    )()
    return OpcodeClass
  return classFactory
)()

# Each opcode has a stack depth factor which is the maximum size that the
# opcode will take the evaluation stack to, and is used later to
# determine the maximum stack size needed for running a script
#
# In most cases this number is static and depends only on the opcode function
# body. To avoid having to maintain the number manually, we parse the opcode
# source and count the number of pushes - pops by transversing the ast. This
# is hacky but seems to do the job
class Counter extends Visitor
  constructor: ->
    @factor = 0
    @current = 0

  CallExpression: (node) ->
    node = super(node)
    if node.callee.type is 'MemberExpression'
      if node.callee.property.type is 'Identifier'
        name =  node.callee.property.name
      else if node.callee.property.type is 'Literal'
        name =  node.callee.property.value
      else
        throw new Error('assert error')
      if name is 'push'
        @current++
      else if name is 'pop'
        @current--
      @factor = Math.max(@factor, @current)
    return node


calculateOpcodeFactor = (opcodeFn) ->
  ast = esprima.parse("(#{opcodeFn.toString()})")
  counter = new Counter()
  counter.visit(ast)
  return counter.factor


Op = (name, fn, factorFn) -> OpcodeClassFactory(name, fn, factorFn)


opcodes = [
  Op 'POP', (f, s, l) -> s.pop()                      # remove top
  Op 'DUP', (f, s, l) -> s.push(s.top())              # duplicate top
  Op 'SWAP', (f, s, l) ->                             # swap top 2 values
    top = s.pop()
    bot = s.pop()
    s.push(top)
    s.push(bot)

  Op 'RET', (f, s, l) -> ret(f)                       # return from function
  Op 'RETV', (f, s, l) ->                             # return value from
    f.fiber.rv = s.pop()                              # function
    ret(f)

  Op 'PAUSE', (f, s) -> f.paused = true               # pause frame
  Op 'YIELD', (f, s) ->                               # yield value from
    f.fiber.yielded = s.pop()                         # generator
    f.fiber.pause()

  Op 'THROW', (f, s, l) -> throwErr(f, s.pop())       # throw something
  Op 'ENTER_GUARD', (f) ->                            # enter guarded region
    f.guards.push(f.script.guards[@args[0]])

  Op 'EXIT_GUARD', (f) ->                             # exit guarded region
    currentGuard = f.guards[f.guards.length - 1]
    specifiedGuard = f.script.guards[@args[0]]
    if specifiedGuard == currentGuard
      f.guards.pop()

  Op 'SR1', (f, s, l) -> f.fiber.r1 = s.pop()         # save to register 1
  Op 'SR2', (f, s, l) -> f.fiber.r2 = s.pop()         # save to register 2
  Op 'SR3', (f, s, l) -> f.fiber.r3 = s.pop()         # save to register 3
  Op 'LR1', (f, s, l) -> s.push(f.fiber.r1)           # load from register 1
  Op 'LR2', (f, s, l) -> s.push(f.fiber.r2)           # load from register 2
  Op 'LR3', (f, s, l) -> s.push(f.fiber.r3)           # load from register 3
  Op 'SREXP', (f, s, l) -> s.fiber.rexp = s.pop()     # save to the
                                                      # expression register

  Op 'ITER', (f, s, l) ->                             # calls 'iterator' method
    callm(f, 0, 'iterator', s.pop())

  Op 'ENUMERATE', (f, s, l, r) ->                     # push iterator that
    s.push(r.enumerateKeys(s.pop()))                  # yields the object
                                                      # enumerable properties

  Op 'NEXT', (f, s, l) ->                             # calls iterator 'next'
    callm(f, 0, 'next', s.pop())
    if f.error instanceof StopIteration
      f.error = null
      f.paused = false
      f.ip = @args[0]

  Op 'FUNCTION_SETUP', (f, s, l) ->                   # prepare the arguments
    l.set(1, s.pop())                                 # object and the self
    fn = s.pop()                                      # reference when the
    if @args[0]                                       # function has a name
      l.set(2, fn)
    # the fiber pushing the arguments object and
    # the self reference cancels this opcode pop calL
  , -> 0

  Op 'GLOBAL', (f, s, l, r) -> s.push(r.global)       # push the global object

  Op 'REST', (f, s, l, r) ->                          # initialize 'rest' param
    index = @args[0]
    varIndex = @args[1]
    args = l.get(1)
    if index < args.length
      l.set(varIndex, Array::slice.call(args, index))

  Op 'NEW', (f, s, l) ->                              # call as constructor
    call(f, @args[0], s.pop(), null, null, true)

  Op 'CALL', (f, s, l) ->                             # call function
    call(f, @args[0], s.pop(), null, @args[1])
     # pop n arguments plus function and push return value
  , -> 1 - (@args[0] + 1)

  Op 'CALLM', (f, s, l) ->                            # call method
    callm(f, @args[0], s.pop(), s.pop(), @args[1])
     # pop n arguments plus function plus target and push return value
  , -> 1 - (@args[0] + 1 + 1)

  Op 'GET', (f, s, l, r) ->                           # get property from
    obj = s.pop()                                     # object
    key = s.pop()
    if not obj?
      return throwErr(f, new VmTypeError(
        "Cannot read property '#{key}' of #{obj}"))
    s.push(r.get(obj, key))

  Op 'SET', (f, s, l, r) ->                           # set property on
    obj = s.pop()                                     # object
    key = s.pop()
    val = s.pop()
    if not obj?
      return throwErr(f, new VmTypeError(
        "Cannot set property '#{key}' of #{obj}"))
    s.push(r.set(obj, key, val))

  Op 'DEL', (f, s, l, r) ->                           # del property on
    obj = s.pop()                                     # object
    key = s.pop()
    if not obj?
      return throwErr(f, new VmTypeError('Cannot convert null to object'))
    s.push(r.del(obj, key))

  Op 'GETL', (f, s, l) ->                             # get local variable
    scopeIndex = @args[0]
    varIndex = @args[1]
    scope = l
    while scopeIndex--
      scope = scope.parent
    s.push(scope.get(varIndex))

  Op 'SETL', (f, s, l) ->                             # set local variable
    scopeIndex = @args[0]
    varIndex = @args[1]
    scope = l
    while scopeIndex--
      scope = scope.parent
    s.push(scope.set(varIndex, s.pop()))

  Op 'GETW', (f, s, l, r) ->
    key = @args[0]
    while l instanceof WithScope
      if l.has(key)
        return s.push(l.get(key))
      l = l.parent
    while l instanceof Scope
      idx = l.name(key)
      if idx >= 0
        return s.push(l.get(idx))
      l = l.parent
    if not hasProp(r.global, key) and not @args[1]
      return throwErr(f, new VmReferenceError("#{key} is not defined"))
    s.push(r.global[key])

  Op 'SETW', (f, s, l, r) ->
    key = @args[0]
    value = s.pop()
    while l instanceof WithScope
      if l.has(key)
        return s.push(l.set(key, value))
      l = l.parent
    while l instanceof Scope
      idx = l.name(key)
      if idx >= 0
        return s.push(l.set(idx, value))
      l = l.parent
    s.push(r.global[key] = value)

  Op 'GETG', (f, s, l, r) ->                          # get global variable
    if not hasProp(r.global, @args[0]) and not @args[1]
      return throwErr(f, new VmReferenceError("#{@args[0]} is not defined"))
    s.push(r.global[@args[0]])

  Op 'SETG', (f, s, l, r) ->                          # set global variable
    s.push(r.global[@args[0]] = s.pop())

  Op 'ENTER_SCOPE', (f) ->                            # enter nested scope
    f.scope = new Scope(f.scope, f.script.localNames, f.script.localLength)

  Op 'EXIT_SCOPE', (f) ->                             # exit nested scope
    f.scope = f.scope.parent

  Op 'ENTER_WITH', (f, s) ->                            # enter 'with' block
    f.scope = new WithScope(f.scope, s.pop())

  Op 'INV', (f, s, l, r) -> s.push(r.inv(s.pop()))            # invert signal
  Op 'LNOT', (f, s, l, r) -> s.push(r.lnot(s.pop()))          # logical NOT
  Op 'NOT', (f, s, l, r) -> s.push(r.not(s.pop()))            # bitwise NOT
  Op 'INC', (f, s, l, r) -> s.push(r.inc(s.pop()))            # increment
  Op 'DEC', (f, s, l, r) -> s.push(r.dec(s.pop()))            # decrement

  Op 'ADD', (f, s, l, r) -> s.push(r.add(s.pop(), s.pop()))   # sum
  Op 'SUB', (f, s, l, r) -> s.push(r.sub(s.pop(), s.pop()))   # difference
  Op 'MUL', (f, s, l, r) -> s.push(r.mul(s.pop(), s.pop()))   # product
  Op 'DIV', (f, s, l, r) -> s.push(r.div(s.pop(), s.pop()))   # division
  Op 'MOD', (f, s, l, r) -> s.push(r.mod(s.pop(), s.pop()))   # modulo
  Op 'SHL', (f, s, l, r) ->  s.push(r.shl(s.pop(), s.pop()))  # left shift
  Op 'SAR', (f, s, l, r) -> s.push(r.sar(s.pop(), s.pop()))   # right shift
  Op 'SHR', (f, s, l, r) -> s.push(r.shr(s.pop(), s.pop()))   # unsigned shift
  Op 'OR', (f, s, l, r) -> s.push(r.or(s.pop(), s.pop()))     # bitwise OR
  Op 'AND', (f, s, l, r) -> s.push(r.and(s.pop(), s.pop()))   # bitwise AND
  Op 'XOR', (f, s, l, r) -> s.push(r.xor(s.pop(), s.pop()))   # bitwise XOR

  Op 'CEQ', (f, s, l, r) -> s.push(r.ceq(s.pop(), s.pop()))   # equals
  Op 'CNEQ', (f, s, l, r) -> s.push(r.cneq(s.pop(), s.pop())) # not equals
  Op 'CID', (f, s, l, r) -> s.push(r.cid(s.pop(), s.pop()))   # same
  Op 'CNID', (f, s, l, r) -> s.push(r.cnid(s.pop(), s.pop())) # not same
  Op 'LT', (f, s, l, r) -> s.push(r.lt(s.pop(), s.pop()))     # less than
  Op 'LTE', (f, s, l, r) -> s.push(r.lte(s.pop(), s.pop()))   # less or equal
                                                              # than

  Op 'GT', (f, s, l, r) -> s.push(r.gt(s.pop(), s.pop()))     # greater than
  Op 'GTE', (f, s, l, r) -> s.push(r.gte(s.pop(), s.pop()))   # greater or
                                                              # equal than

  Op 'IN', (f, s, l, r) ->                                    # property in obj
    s.push(r.has(s.pop(), s.pop()))                           # prototype chain

  Op 'INSTANCEOF', (f, s, l, r) ->                    # instance of
    s.push(r.instanceOf(s.pop(), s.pop()))

  Op 'TYPEOF', (f, s, l, r) ->                        # instance of
    s.push(typeof s.pop())

  Op 'VOID', (f, s) ->
    s.pop()
    s.push(undefined)

  Op 'JMP', (f, s, l) -> f.ip = @args[0]              # unconditional jump
  Op 'JMPT', (f, s, l) -> f.ip = @args[0] if s.pop()  # jump if true
  Op 'JMPF', (f, s, l) -> f.ip = @args[0] if not s.pop()# jump if false

  Op 'UNDEF', (f, s) ->
    s.push(undefined)

  Op 'LITERAL', (f, s, l) ->                          # push literal value
    s.push(@args[0])

  Op 'STRING_LITERAL', (f, s, l) ->                   # push string object
    s.push(f.script.strings[@args[0]])

  Op 'REGEXP_LITERAL', (f, s, l, r) ->                # push regexp object
    s.push(new RegExpProxy(f.script.regexps[@args[0]], r))

  Op 'OBJECT_LITERAL', (f, s, l, r) ->                # object literal
    length = @args[0]
    rv = {}
    while length--
      r.set(rv, s.pop(), s.pop())
    s.push(rv)
    # pops one item for each key/value and push the object
  , -> 1 - (@args[0] * 2)

  Op 'ARRAY_LITERAL', (f, s, l, r) ->                 # array literal
    length = @args[0]
    rv = new Array(length)
    while length--
      rv[length] = s.pop()
    s.push(rv)
     # pops each element and push the array
  , -> 1 - @args[0]

  Op 'FUNCTION', (f, s, l, r) ->                      # push function reference
    # get the index of the script with function code
    scriptIndex = @args[0]
    # create a new function, passing the current local scope
    s.push(createFunction(f.script.scripts[scriptIndex], l, r, @args[1]))

  # debug related opcodes
  Op 'LINE', (f) -> f.setLine(@args[0])               # set line number
  Op 'COLUMN', (f) -> f.setColumn(@args[0])           # set column number
  Op 'DEBUG', (f, s, l) -> debug()                    # pause and notify
                                                      # attached debugger
]


throwErr = (frame, err) ->
  frame.error = err
  frame.paused = true


# Helpers shared between some opcodes

callm = (frame, length, key, target, name) ->
  {evalStack: stack, realm} = frame
  if not target?
    id = 'null'
    if target == undefined
      id = 'undefined'
    return throwErr(frame, new VmTypeError(
      "Cannot call method '#{key}' of #{id}"))
  constructor = target.constructor
  targetName = constructor.__name__ or constructor.name or 'Object'
  name = "#{targetName}.#{name}"
  func = realm.get(target, key)
  if func instanceof Function
    return call(frame, length, func, target, name)
  if not func?
    stack.pop() # pop target
    throwErr(frame, new VmTypeError(
      "Object #<#{targetName}> has no method '#{key}'"))
  else
    stack.pop() # pop target
    throwErr(frame, new VmTypeError(
      "Property '#{key}' of object #<#{targetName}> is not a function"))


call = (frame, length, func, target, name, construct) ->
  if typeof func != 'function'
    return throwErr(frame, new VmTypeError(
      "object is not a function"))
  {evalStack: stack, fiber, realm} = frame
  args = {length: length, callee: func}
  while length
    args[--length] = stack.pop()
  target = target or realm.global
  push = true
  args = Array::slice.call(args)
  if func in [Function, realm.eval]
    try
      if func == Function
        # dynamically create a new Function instance
        stack.push(createFunction(realm.compileFunction(args), null, realm))
      else
        # evaluate string in the current frame
        script = realm.eval(frame, args[0])
        frame.paused = true
        fiber.pushEvalFrame(frame, script)
    catch e
      throwErr(frame, new VmEvalError(e.message))
    return
  if hasProp(func, '__vmfunction__')
    func.__callname__ = name
    func.__fiber__ = fiber
    func.__construct__ = construct
    push = false
  try
    if construct
      # create a native class instance
      val = createNativeInstance(func, args)
    else
      val = func.apply(target, args)
    if push and not fiber.paused
      stack.push(val)
  catch nativeError
    throwErr(frame, nativeError)


createGenerator = (caller, script, scope, realm, target, args, fn, callname) ->
  if caller
    timeout = caller.timeout
  fiber = new Fiber(realm, timeout)
  frame = fiber.pushFrame(script, target, scope, args, fn, callname, false)
  newborn = true

  send = (obj) ->
    if newborn and obj != undefined
      throw new VmTypeError(
        'no argument must be passed when starting generator')
    if fiber.done()
      throw new VmError('generator closed')
    frame = fiber.callStack[fiber.depth]
    if newborn
      newborn = false
      fiber.run()
    else
      frame.evalStack.push(obj)
      fiber.resume()
    if caller
      # transfer timeout back to the caller fiber
      caller.timeout = fiber.timeout
    if fiber.done()
      rv.closed = true
      throw new StopIteration(fiber.rv, 'generator has stopped')
    return fiber.yielded

  thrw = (e) ->
    if newborn
      close()
      return e
    if fiber.done()
      throw new VmError('generator closed')
    frame = fiber.callStack[fiber.depth]
    frame.error = e
    fiber.resume()
    if caller
      caller.timeout = fiber.timeout
    if fiber.done()
      return fiber.rv
    return fiber.yielded

  close = ->
    if fiber.done()
      return
    if newborn
      fiber.depth = -1
    # force a return
    frame = fiber.callStack[fiber.depth]
    frame.evalStack.clear()
    frame.ip = frame.exitIp
    fiber.resume()
    if caller
      caller.timeout = fiber.timeout
    return fiber.rv

  rv = {
    next: send
    send: send
    throw: thrw
    close: close
    closed: false
    iterator: -> rv
  }

  return rv

createFunction = (script, scope, realm, generator) ->
  if generator
    rv = ->
      name = rv.__callname__ or script.name
      gen = createGenerator(rv.__fiber__, script, scope, realm, this,
        arguments, rv, name)
      if not (fiber = rv.__fiber__)
        return gen
      fiber.callStack[fiber.depth].evalStack.push(gen)
      rv.__fiber__ = null
      rv.__callname__ = null
  else
    rv = ->
      run = false
      if fiber = rv.__fiber__
        fiber.callStack[fiber.depth].paused = true
        rv.__fiber__ = null
        construct = rv.__construct__
        rv.__construct__ = null
      else
        fiber = new Fiber(realm)
        run = true
      name = rv.__callname__ or script.name
      rv.__callname__ = null
      fiber.pushFrame(script, this, scope, arguments, rv, name, construct)
      if run
        fiber.run()
        return fiber.rv
  defProp(rv, '__vmfunction__', {value: true})
  defProp(rv, '__source__', {value: script.source})
  defProp(rv, '__name__', {value: script.name})
  defProp(rv, '__construct__', {value: null, writable: true})
  defProp(rv, '__fiber__', {value: null, writable: true})
  defProp(rv, '__callname__', {value: null, writable: true})
  return rv


ret = (frame) ->
  frame.evalStack.clear()
  frame.exitIp = frame.ip
  # frame.ip = frame.exitIp


debug = ->


# ugly but the only way I found to create native classes instances with a
# variable number of arguments

callDateConstructor = (a) ->
  switch a.length
    when 0
      rv = new Date()
    when 1
      rv = new Date(a[0])
    when 2
      rv = new Date(a[0], a[1])
    when 3
      rv = new Date(a[0], a[1], a[2])
    when 4
      rv = new Date(a[0], a[1], a[2], a[3])
    when 5
      rv = new Date(a[0], a[1], a[2], a[3], a[4])
    when 6
      rv = new Date(a[0], a[1], a[2], a[3], a[4], a[5])
    else
      rv = new Date(a[0], a[1], a[2], a[3], a[4], a[5], a[6])
  return rv


callArrayConstructor = (a) ->
  if a.length == 1 and (a[0] | 0) == a[0]
    return new Array(a[0])
  return a.slice()


callRegExpConstructor = (a) ->
  if a.length == 1
    return new RegExp(a[0])
  else
    return new RegExp(a[0], a[1])


createNativeInstance = (constructor, args) ->
  if constructor == Date
    return callDateConstructor(args)
  else if constructor == Array
    return callArrayConstructor(args)
  else if constructor == RegExp
    return callRegExpConstructor(args)
  else if constructor == Number
    return new Number(args[0])
  else if constructor == Boolean
    return new Boolean(args[0])
  else
    # create a new object linked to the function prototype by using
    # a constructor proxy
    constructorProxy = -> constructor.apply(this, args)
    constructorProxy.prototype = constructor.prototype
    rv = new constructorProxy()
    return rv


module.exports = opcodes
