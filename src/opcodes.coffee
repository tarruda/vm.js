{PropertiesIterator} = require './engine/util'

OpcodeClassFactory = (->
  # opcode id, correspond to the index in the opcodes array and is used
  # to represent serialized opcodes
  id = 0

  classFactory = (name, fn) ->
    # generate opcode class
    OpcodeClass = (->
      # this is ugly but its the only way I found to get nice opcode
      # names when debugging with node-inspector/chrome dev tools
      constructor = eval(
        "(function #{name}(args) { if (args) this.args = args; })")
      constructor::id = id++
      constructor::name = name
      constructor::exec = fn
      return constructor
    )()
    return OpcodeClass
  return classFactory
)()

Op = (name, fn) -> OpcodeClassFactory(name, fn)

opcodes = [
  Op 'POP', (f, s, l) -> s.pop()                      # remove top
  Op 'DUP', (f, s, l) -> s.push(s.top())              # duplicate top
  Op 'SCOPE', (f, s, l) -> s.push(f.scope)            # push local scope
                                                      # reference

  Op 'RET', (f, s, l) -> f.ret()                      # return from function
  Op 'RETV', (f, s, l) -> f.retv(s.pop())             # return value from
                                                      # function

  Op 'THROW', (f, s, l) -> f.throw(s.pop())           # throw something
  Op 'DEBUG', (f, s, l) -> f.debug()                  # pause execution
  Op 'SR1', (f, s, l) -> f.r1 = s.pop()               # save to register 1
  Op 'SR2', (f, s, l) -> f.r2 = s.pop()               # save to register 2
  Op 'SR3', (f, s, l) -> f.r3 = s.pop()               # save to register 3
  Op 'SR4', (f, s, l) -> f.r4 = s.pop()               # save to register 4
  Op 'LR1', (f, s, l) -> s.push(f.r1)                 # load from register 1
  Op 'LR2', (f, s, l) -> s.push(f.r2)                 # load from register 2
  Op 'LR3', (f, s, l) -> s.push(f.r3)                 # load from register 3
  Op 'LR4', (f, s, l) -> s.push(f.r4)                 # load from register 4
  Op 'SREXP', (f, s, l) -> s.rexp = s.pop()           # save to on the
                                                      # expression register

  Op 'ITER_PROPS', (f, s, l) ->                       # iterator that yields
    s.push(new PropertiesIterator(s.pop()))           # enumerable properties

  Op 'REST', (f, s, l) ->                             # initialize 'rest' param
    f.rest(@args[0], @args[1])

  Op 'CALL', (f, s, l) ->                             # call function
    f.call(@args[0], @args[1])

  Op 'GET', (f, s, l) ->                              # get property from
    s.push(f.get(s.pop(), s.pop()))                   # object

  Op 'SET', (f, s, l) ->                              # set property on
    f.set(s.pop(), s.pop(), s.pop())                  # object

  Op 'INV', (f, s, l) -> s.push(-s.pop())             # invert signal
  Op 'LNOT', (f, s, l) -> s.push(!s.pop())            # logical NOT
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
  Op 'CID', (f, s, l) -> s.push(s.pop() == s.pop())   # same
  Op 'CNID', (f, s, l) -> s.push(s.pop() != s.pop())  # not same
  Op 'LT', (f, s, l) -> s.push(s.pop() < s.pop())     # less than
  Op 'LTE', (f, s, l) -> s.push(s.pop() <= s.pop())   # less or equal than
  Op 'GT', (f, s, l) -> s.push(s.pop() > s.pop())     # greater than
  Op 'GTE', (f, s, l) -> s.push(s.pop() >= s.pop())   # greater or equal than
  Op 'IN', (f, s, l) -> s.push(s.pop() of s.pop())    # contains property
  Op 'INSTANCE_OF', (f, s, l) ->                      # instance of
    s.push(s.pop() instanceof s.pop())

  Op 'JMP', (f, s, l) -> f.jump(@args[0])             # unconditional jump
  Op 'JMPT', (f, s, l) -> f.jump(@args[0]) if s.pop() # jump if true
  Op 'JMPF', (f, s, l) -> f.jump(@args[0]) if !s.pop()# jump if false

  Op 'LITERAL', (f, s, l) ->                          # push literal value
    s.push(@args[0])

  Op 'OBJECT_LITERAL', (f, s, l) ->                   # object literal
    length = @args[0]
    rv = {}
    while length--
      rv[s.pop()] = s.pop()
    s.push(rv)

  Op 'ARRAY_LITERAL', (f, s, l) ->                    # array literal
    length = @args[0]
    rv = new Array(length)
    while length--
      rv[length] = s.pop()
    s.push(rv)

  Op 'FUNCTION', (f, s, l) -> f.fn(@args[0])          # push function reference
]

module.exports = opcodes
