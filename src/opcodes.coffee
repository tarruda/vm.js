OpcodeClassFactory = (->
  # opcode id, correspond to the index in the opcodes array and is used
  # to represent serialized opcodes
  id = 0

  classFactory = (name, argc, fn, opc) ->
    # generate opcode class
    OpcodeClass = (->
      # this is ugly but its the only way I found to get nice opcode
      # names when debugging with web inspector
      constructor = eval("(function #{name}(args) { this.args = args; })")
      constructor::id = id++
      constructor::name = name
      constructor::opc = opc
      if typeof argc == 'function'
        constructor::execImpl = argc
        constructor::argc = 0
      else
        constructor::execImpl = fn
        constructor::argc = argc
      if constructor::argc && opc
        constructor::exec = (f) ->
          @execImpl.apply(this, [f].concat(@args, f.popn(@opc)))
      else if constructor::argc
        constructor::exec = (f) ->
          @execImpl.apply(this, [f].concat(@args))
      else if opc
        constructor::exec = (f) ->
          @execImpl.apply(this, [f].concat(f.popn(@opc)))
      else
        constructor::exec = (f) ->
          @execImpl(f)
      return constructor
    )()
    return OpcodeClass
  return classFactory
)()

Op = (name, argc, fn) -> OpcodeClassFactory(name, argc, fn, 0)
UOp = (name, argc, fn) -> OpcodeClassFactory(name, argc, fn, 1)
BOp = (name, argc, fn) -> OpcodeClassFactory(name, argc, fn, 2)
TOp = (name, argc, fn) -> OpcodeClassFactory(name, argc, fn, 3)

opcodes = [
  # 0-arg opcodes
  Op 'NOOP', (f) ->                                # no-op
  Op 'POP', (f) -> f.pop()                         # remove top
  Op 'SWAP', (f) -> f.swap()                       # swap the top 2
  Op 'DUP', (f) -> f.dup()                         # duplicate top item
  Op 'DUP2', (f) -> f.dup2()                       # duplicate top 2 items
  Op 'PUSH_SCOPE', (f) -> f.pushScope()            # push local scope reference
  Op 'SAVE', (f) -> f.save()                       # pop/save top of stack
  Op 'SAVE2', (f) -> f.save2()                     # pop/save top 2 items
  Op 'LOAD', (f) -> f.load()                       # push saved value
  Op 'LOAD2', (f) -> f.load2()                      # push 2 saved values

  # 0-arg unary opcodes
  UOp 'INV', (f, o) -> f.push(-o)                  # invert signal
  UOp 'LNOT', (f, o) -> f.push(!o)                 # logical NOT
  UOp 'NOT', (f, o) -> f.push(~o)                  # bitwise NOT

  # 0-args binary opcodes
  BOp 'GET', (f, n, o) -> f.push(f.get(o, n))      # get name from object
                                                   # by the one below
  BOp 'ADD', (f, r, l) -> f.push(l + r)            # sum
  BOp 'SUB', (f, r, l) -> f.push(l - r)            # difference
  BOp 'MUL', (f, r, l) -> f.push(l * r)            # product
  BOp 'DIV', (f, r, l) -> f.push(l / r)            # division
  BOp 'MOD', (f, r, l) -> f.push(l % r)            # modulo
  BOp 'SHL', (f, r, l) ->  f.push(l << r)          # left shift
  BOp 'SAR', (f, r, l) -> f.push(l >> r)           # right shift
  BOp 'SHR', (f, r, l) -> f.push(l >>> r)          # unsigned right shift
  BOp 'OR', (f, r, l) -> f.push(l | r)             # bitwise OR
  BOp 'AND', (f, r, l) -> f.push(l & r)            # bitwise AND
  BOp 'XOR', (f, r, l) -> f.push(l ^ r)            # bitwise XOR
  # tests
  BOp 'CEQ', (f, r, l) -> f.push(`l == r`)         # equals
  BOp 'CNEQ', (f, r, l) -> f.push(`l != r`)        # not equals
  BOp 'CID', (f, r, l) -> f.push(l == r)           # same
  BOp 'CNID', (f, r, l) -> f.push(l != r)          # not same
  BOp 'LT', (f, r, l) -> f.push(l < r)             # less than
  BOp 'LTE', (f, r, l) -> f.push(l <= r)           # less or equal than
  BOp 'GT', (f, r, l) -> f.push(l > r)             # greater than
  BOp 'GTE', (f, r, l) -> f.push(l >= r)           # greater or equal than
  BOp 'IN', (f, r, l) -> f.push(l of r)            # contains property
  BOp 'INSTANCE_OF', (f, r, l) ->                  # instance of
    f.push(l instanceof r)
  # logical
  BOp 'LOR', (f, r, l) -> f.push(l || r)           # logical OR
  BOp 'LAND', (f, r, l) -> f.push(l && r)          # logical AND

  # 0-arg ternary opcodes
  TOp 'SET', (f, n, o, v) -> f.set(o, n, v)        # set name = val on object

  Op 'LITERAL', 1, (f, value) -> f.push(value)     # push literal value
  Op 'OBJECT_LITERAL', 1, (f, length) ->           # object literal
    rv = {}
    while length--
      value = f.pop()
      rv[f.pop()] = value
    f.push(rv)
  Op 'ARRAY_LITERAL', 1, (f, length) ->            # array literal
    rv = new Array(length)
    while length--
      rv[length] = f.pop()
    f.push(rv)

  # jumps
  Op 'JMP', 1, (f, ip) -> f.jump(ip)               # unconditional jump
  Op 'JMPT', 1, (f, ip) -> f.jump(ip) if f.pop()   # jump if true
  Op 'JMPF', 1, (f, ip) -> f.jump(ip) if !f.pop()  # jump if false
]

module.exports = opcodes
