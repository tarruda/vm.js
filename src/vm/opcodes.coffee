Visitor = require '../ast/visitor'
{StopIteration, ArrayIterator} = require '../runtime/util'
{VmTypeError, VmReferenceError} = require '../runtime/errors'
{VmObject} = require '../runtime/internal'
{Closure, Scope, WithScope} = require './thread'

OpcodeClassFactory = (->
  # opcode id, correspond to the index in the opcodes array and is used
  # to represent serialized opcodes
  id = 0

  classFactory = (name, fn, calculateFactor) ->
    # generate opcode class
    OpcodeClass = (->
      # this is ugly but its the only way I found to get nice opcode
      # names when debugging with node-inspector/chrome dev tools
      constructor = eval(
        "(function #{name}(args) { if (args) this.args = args; })")
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
  Op 'RET', (f, s, l) -> ret(f)                       # return from function
  Op 'RETV', (f, s, l) ->                             # return value from
    f.fiber.rv = s.pop()                              # function
    ret(f)

  Op 'THROW', (f, s, l) -> throwErr(f, s.pop())       # throw something
  Op 'SR1', (f, s, l) -> f.r1 = s.pop()               # save to register 1
  Op 'SR2', (f, s, l) -> f.r2 = s.pop()               # save to register 2
  Op 'SR3', (f, s, l) -> f.r3 = s.pop()               # save to register 3
  Op 'SR4', (f, s, l) -> f.r4 = s.pop()               # save to register 4
  Op 'LR1', (f, s, l) -> s.push(f.r1)                 # load from register 1
  Op 'LR2', (f, s, l) -> s.push(f.r2)                 # load from register 2
  Op 'LR3', (f, s, l) -> s.push(f.r3)                 # load from register 3
  Op 'LR4', (f, s, l) -> s.push(f.r4)                 # load from register 4
  Op 'SREXP', (f, s, l) -> s.rexp = s.pop()           # save to the
                                                      # expression register

  Op 'ITER', (f, s, l) ->                             # calls 'iterator' method
    callm(f, 0, 'iterator', s.pop())

  Op 'ENUMERATE', (f, s, l, c) ->                     # push iterator that
    target = s.pop()                                  # yields the object
    if target instanceof VmObject                     # enumerable properties
      iterator = target.enumerate()
    else
      keys = []
      for k of target
        keys.push(k)
      iterator = new ArrayIterator(keys)
    s.push(iterator)

  Op 'NEXT', (f, s, l) ->                             # calls iterator 'next'
    callm(f, 0, 'next', s.pop())
    if f.fiber.error == StopIteration
      f.fiber.error = null
      f.paused = false
      f.ip = @args[0]

  Op 'ARGS', (f, s, l) ->                             # prepare the 'arguments'
    l.set(1, s.pop())                                 # object
    # the fiber pushing the arguments object cancels
    # this opcode pop calL
  , -> 0

  Op 'GLOBAL', (f, s, l, c) -> s.push(c.global)       # push the global object

  Op 'REST', (f, s, l, c) ->                          # initialize 'rest' param
    index = @args[0]
    varIndex = @args[1]
    args = l.get(1)
    if index < args.length
      l.set(varIndex, Array::slice.call(args, index))

  Op 'CALL', (f, s, l) ->                             # call function
    call(f, @args[0], s.pop(), null, @args[1])
     # pop n arguments plus function and push return value
  , -> 1 - (@args[0] + 1)

  Op 'CALLM', (f, s, l) ->                            # call method
    callm(f, @args[0], s.pop(), s.pop(), @args[1])
     # pop n arguments plus function plus target and push return value
  , -> 1 - (@args[0] + 1 + 1)

  Op 'GET', (f, s, l, c) ->                           # get property from
    obj = s.pop()                                     # object
    key = s.pop()
    if not obj?
      return throwErr(f, new VmTypeError(
        "Cannot read property '#{key}' of #{obj}"))
    s.push(c.get(obj, key))

  Op 'SET', (f, s, l, c) ->                           # set property on
    obj = s.pop()                                     # object
    key = s.pop()
    val = s.pop()
    if not obj?
      return throwErr(f, new VmTypeError(
        "Cannot set property '#{key}' of #{obj}"))
    s.push(c.set(obj, key, val))

  Op 'DEL', (f, s, l) ->                              # del property on
    obj = s.pop()                                     # object
    key = s.pop()
    if not obj?
      return throwErr(f, new VmTypeError('Cannot convert null to object'))
    s.push(c.del(obj, key))

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

  Op 'GETW', (f, s, l, c) ->
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
    if key not of c.global
      return throwErr(f, new VmReferenceError("#{key} is not defined"))
    s.push(c.global[key])

  Op 'SETW', (f, s, l, c) ->
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
    s.push(c.global[key] = value)

  Op 'GETG', (f, s, l, c) ->                          # get global variable
    if @args[0] not of c.global
      return throwErr(f, new VmReferenceError("#{@args[0]} is not defined"))
    s.push(c.global[@args[0]])

  Op 'SETG', (f, s, l, c) ->                          # set global variable
    s.push(c.global[@args[0]] = s.pop())

  Op 'ENTER_SCOPE', (f) ->                            # enter nested scope
    f.scope = new Scope(f.scope, f.script.localNames, f.script.localLength)

  Op 'EXIT_SCOPE', (f) ->                             # exit nested scope
    f.scope = f.scope.parent

  Op 'ENTER_WITH', (f, s) ->                            # enter 'with' block
    f.scope = new WithScope(f.scope, s.pop())

  Op 'INV', (f, s, l) -> s.push(-s.pop())             # invert signal
  Op 'LNOT', (f, s, l) -> s.push(not s.pop())         # logical NOT
  Op 'NOT', (f, s, l) -> s.push(~s.pop())             # bitwise NOT
  Op 'INC', (f, s, l) -> s.push(s.pop() + 1)          # increment
  Op 'DEC', (f, s, l) -> s.push(s.pop() - 1)          # decrement

  Op 'ADD', (f, s, l) -> s.push(s.pop() + s.pop())    # sum
  Op 'SUB', (f, s, l) -> s.push(s.pop() - s.pop())    # difference
  Op 'MUL', (f, s, l) -> s.push(s.pop() * s.pop())    # product
  Op 'DIV', (f, s, l) -> s.push(s.pop() / s.pop())    # division
  Op 'MOD', (f, s, l) -> s.push(s.pop() % s.pop())    # modulo
  Op 'SHL', (f, s, l) ->  s.push(s.pop() << s.pop())  # left shift
  Op 'SAR', (f, s, l) -> s.push(s.pop() >> s.pop())   # right shift
  Op 'SHR', (f, s, l) -> s.push(s.pop() >>> s.pop())  # unsigned right shift
  Op 'OR', (f, s, l) -> s.push(s.pop() | s.pop())     # bitwise OR
  Op 'AND', (f, s, l) -> s.push(s.pop() & s.pop())    # bitwise AND
  Op 'XOR', (f, s, l) -> s.push(s.pop() ^ s.pop())    # bitwise XOR

  Op 'CEQ', (f, s, l) -> s.push(`s.pop() == s.pop()`) # equals
  Op 'CNEQ', (f, s, l) -> s.push(`s.pop() != s.pop()`)# not equals
  Op 'CID', (f, s, l) -> s.push(s.pop() is s.pop())   # same
  Op 'CNID', (f, s, l) -> s.push(s.pop() isnt s.pop())# not same
  Op 'LT', (f, s, l) -> s.push(s.pop() < s.pop())     # less than
  Op 'LTE', (f, s, l) -> s.push(s.pop() <= s.pop())   # less or equal than
  Op 'GT', (f, s, l) -> s.push(s.pop() > s.pop())     # greater than
  Op 'GTE', (f, s, l) -> s.push(s.pop() >= s.pop())   # greater or equal than
  Op 'IN', (f, s, l) -> s.push(s.pop() of s.pop())    # contains property
  Op 'INSTANCE_OF', (f, s, l) ->                      # instance of
    s.push(s.pop() instanceof s.pop())

  Op 'JMP', (f, s, l) -> f.ip = @args[0]              # unconditional jump
  Op 'JMPT', (f, s, l) -> f.ip = @args[0] if s.pop()  # jump if true
  Op 'JMPF', (f, s, l) -> f.ip = @args[0] if not s.pop()# jump if false

  Op 'LITERAL', (f, s, l) ->                          # push literal value
    s.push(@args[0])

  Op 'OBJECT_LITERAL', (f, s, l, c) ->                # object literal
    length = @args[0]
    rv = {}
    while length--
      rv[s.pop()] = s.pop()
    s.push(rv)
    # pops one item for each key/value and push the object
  , -> 1 - (@args[0] * 2)

  Op 'ARRAY_LITERAL', (f, s, l, c) ->                 # array literal
    length = @args[0]
    rv = new Array(length)
    while length--
      rv[length] = s.pop()
    s.push(rv)
     # pops each element and push the array
  , -> 1 - @args[0]

  Op 'FUNCTION', (f, s, l) ->                         # push function reference
    # get the index of the script with function code
    scriptIndex = @args[0]
    # create a new closure, passing the current local scope
    fn = new Closure(f.script.scripts[scriptIndex], l)
    s.push(fn)

  # debug related opcodes
  Op 'LINE', (f) -> f.setLine(@args[0])               # set line number
  Op 'COLUMN', (f) -> f.setColumn(@args[0])           # set column number
  Op 'DEBUG', (f, s, l) -> debug()                    # pause and notify
                                                      # attached debugger
]


throwErr = (frame, err) ->
  frame.fiber.error = err
  frame.paused = true


# Helpers shared between some opcodes
callm = (frame, length, key, target, name) ->
  stack = frame.evalStack
  context = frame.context
  if target instanceof VmObject
    targetName = 'VmObject' # FIXME
  else
    targetName = target.constructor.name
  name = "#{targetName}.#{name}"
  func = context.get(target, key)
  if func instanceof Closure
    if func.name
      name = func.name
    return call(frame, length, func, target, name)
  if func instanceof Function
    return call(frame, length, func, target, name)
  if not func?
    throwErr(frame, new VmTypeError("Object #{target} has no method '#{key}'"))
  else
    throwErr(frame, new VmTypeError(
      "Property '#{key}' of object #{target} is not a function"))


call = (frame, length, func, target, name) ->
  stack = frame.evalStack
  context = frame.context
  if not (func instanceof Closure) and not (func instanceof Function)
    return throwErr(frame, new VmTypeError("Object #{func} is not a function"))
  args = {length: length, callee: func}
  while length
    args[--length] = stack.pop()
  if func instanceof Function
    # 'native' function, execute and push to the evaluation stack
    try
      stack.push(func.apply(target, Array::slice.call(args)))
    catch nativeError
      throwErr(frame, nativeError)
  else
    frame.paused = true
    frame.fiber.pushFrame(func, args, name, target)


ret = (frame) ->
  if frame.finalizer
    frame.ip = frame.finalizer
    frame.finalizer = null
  else
    frame.ip = frame.exitIp

debug = ->

module.exports = opcodes
