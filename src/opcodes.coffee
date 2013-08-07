{PropertiesIterator} = require './engine/util'

OpcodeClassFactory = (->
  # opcode id, correspond to the index in the opcodes array and is used
  # to represent serialized opcodes
  id = 0

  classFactory = (name, fn) ->
    # generate opcode class
    OpcodeClass = (->
      # this is ugly but its the only way I found to get nice opcode
      # names when debugging with web inspector
      constructor = eval(
        "(function #{name}(args) { if (args) this.args = args; })")
      constructor::id = id++
      constructor::name = name
      constructor::exec = fn
      # if typeof argc == 'function'
      #   # constructor::execImpl = argc
      #   constructor::argc = 0
      # else
        # constructor::execImpl = fn
        # constructor::argc = argc
      # if constructor::argc && opc
      #   constructor::exec = (f, s) ->
      #     @execImpl.apply(this, [f, s].concat(@args, f.popn(@opc)))
      # else if constructor::argc
      #   constructor::exec = (f, s) ->
      #     @execImpl.apply(this, [f, s].concat(@args))
      # else if opc
      #   constructor::exec = (f, s) ->
      #     @execImpl.apply(this, [f, s].concat(f.popn(@opc)))
      # else
      #   constructor::exec = (f, s) ->
      #     @execImpl(f, s)
      return constructor
    )()
    return OpcodeClass
  return classFactory
)()

Op = (name, fn) -> OpcodeClassFactory(name, fn)

opcodes = [
  Op 'POP', (f, s) -> s.pop()                      # remove top
  Op 'DUP', (f, s) -> s.push(s.top())              # duplicate top
  Op 'SCOPE', (f, s) -> s.push(f.scope)            # push local scope reference
  Op 'RET', (f, s) -> f.ret()                      # return from function
  Op 'RETV', (f, s) -> f.retv(s.pop())             # return value from function
  Op 'THROW', (f, s) -> f.throw(s.pop())           # throw something
  Op 'DEBUG', (f, s) -> f.debug()                  # pause execution
  Op 'SR1', (f, s) -> f.r1 = s.pop()               # save to register 1
  Op 'SR2', (f, s) -> f.r2 = s.pop()               # save to register 2
  Op 'SR3', (f, s) -> f.r3 = s.pop()               # save to register 3
  Op 'SR4', (f, s) -> f.r4 = s.pop()               # save to register 4
  Op 'LR1', (f, s) -> s.push(f.r1)                 # load from register 1
  Op 'LR2', (f, s) -> s.push(f.r2)                 # load from register 2
  Op 'LR3', (f, s) -> s.push(f.r3)                 # load from register 3
  Op 'LR4', (f, s) -> s.push(f.r4)                 # load from register 4
  Op 'SREXP', (f, s) -> s.rexp = s.pop()           # save to the stack
                                                   # expression register

  Op 'ITER_PROPS', (f, s) ->                       # iterator that yields
    s.push(new PropertiesIterator(s.pop()))        # enumerable properties

  Op 'REST_INIT', (f, s) ->                        # initialize 'rest' param
    f.restInit(@args[0], @args[1])

  Op 'CALL', (f, s) ->                             # call function
    f.call(@args[0], @args[1])

  Op 'GET', (f, s) ->                              # get name from object
    n = s.pop()
    o = s.pop()
    s.push(f.get(o, n))

  Op 'SET', (f, s) ->                              # set name = val on object
    v = s.pop()
    n = s.pop()
    o = s.pop()
    f.set(o, n, v)

  Op 'INV', (f, s) -> s.push(-s.pop())             # invert signal
  Op 'LNOT', (f, s) -> s.push(!s.pop())            # logical NOT
  Op 'NOT', (f, s) -> s.push(~s.pop())             # bitwise NOT
  Op 'INC', (f, s) -> s.push(s.pop() + 1)          # increment
  Op 'DEC', (f, s) -> s.push(s.pop() - 1)          # decrement

  Op 'ADD', (f, s) -> s.push(s.pop() + s.pop())    # sum
  Op 'SUB', (f, s) -> s.push(s.pop() - s.pop())    # difference
  Op 'MUL', (f, s) -> s.push(s.pop() * s.pop())    # product
  Op 'DIV', (f, s) -> s.push(s.pop() / s.pop())    # division
  Op 'MOD', (f, s) -> s.push(s.pop() % s.pop())    # modulo
  Op 'SHL', (f, s) ->  s.push(s.pop() << s.pop())  # left shift
  Op 'SAR', (f, s) -> s.push(s.pop() >> s.pop())   # right shift
  Op 'SHR', (f, s) -> s.push(s.pop() >>> s.pop())  # unsigned right shift
  Op 'OR', (f, s) -> s.push(s.pop() | s.pop())     # bitwise OR
  Op 'AND', (f, s) -> s.push(s.pop() & s.pop())    # bitwise AND
  Op 'XOR', (f, s) -> s.push(s.pop() ^ s.pop())    # bitwise XOR
  # tests
  Op 'CEQ', (f, s) -> s.push(`s.pop() == s.pop()`) # equals
  Op 'CNEQ', (f, s) -> s.push(`s.pop() != s.pop()`)# not equals
  Op 'CID', (f, s) -> s.push(s.pop() == s.pop())   # same
  Op 'CNID', (f, s) -> s.push(s.pop() != s.pop())  # not same
  Op 'LT', (f, s) -> s.push(s.pop() < s.pop())     # less than
  Op 'LTE', (f, s) -> s.push(s.pop() <= s.pop())   # less or equal than
  Op 'GT', (f, s) -> s.push(s.pop() > s.pop())     # greater than
  Op 'GTE', (f, s) -> s.push(s.pop() >= s.pop())   # greater or equal than
  Op 'IN', (f, s) -> s.push(s.pop() of s.pop())    # contains property

  Op 'INSTANCE_OF', (f, s) ->                      # instance of
    s.push(s.pop() instanceof s.pop())

  Op 'JMP', (f, s) -> f.jump(@args[0])             # unconditional jump
  Op 'JMPT', (f, s) -> f.jump(@args[0]) if s.pop() # jump if true
  Op 'JMPF', (f, s) -> f.jump(@args[0]) if !s.pop()# jump if false

  Op 'LITERAL', (f, s) ->                          # push literal value
    s.push(@args[0])

  Op 'OBJECT_LITERAL', (f, s) ->                   # object literal
    length = @args[0]
    rv = {}
    while length--
      value = s.pop()
      rv[s.pop()] = value
    s.push(rv)

  Op 'ARRAY_LITERAL', (f, s) ->                    # array literal
    length = @args[0]
    rv = new Array(length)
    while length--
      rv[length] = s.pop()
    s.push(rv)

  Op 'FUNCTION', (f, s) -> f.fn(@args[0])          # push function reference
]

module.exports = opcodes
