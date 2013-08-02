OpcodeClassFactory = (->
  # opcode id, correspond to the index in the opcodes array and is used
  # to represent serialized opcodes
  id = 0

  classFactory = (name, argc, fn, opc) ->
    # generate opcode class
    OpcodeClass = (->
      # this is ugly but its the only way I found to get nice opcode
      # names when debugging with web inspector
      constructor = eval "(function #{name}(args) { this.args = args; })"
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
        constructor::exec = (s) ->
          @execImpl.apply(this, [s].concat(@args, s.splice(@opc)))
      else if constructor::argc
        constructor::exec = (s) ->
          @execImpl.apply(this, [s].concat(@args))
      else if opc
        constructor::exec = (s) ->
          @execImpl.apply(this, [s].concat(s.splice(@opc)))
      else
        constructor::exec = (s) ->
          @execImpl(s)
      return constructor
    )()
    return OpcodeClass
  return classFactory
)()

Op = (name, argc, fn) -> OpcodeClassFactory(name, argc, fn, 0)
UOp = (name, argc, fn) -> OpcodeClassFactory(name, argc, fn, 1)
BOp = (name, argc, fn) -> OpcodeClassFactory(name, argc, fn, 2)

opcodes = [
  # 0-arg opcodes
  Op 'DUP', (s) -> s.push(s.top())                 # duplicate top of stack

  # 0-args binary opcodes
  BOp 'SWAP', (s, b, t) -> s.push(b); s.push(t)    # swap the top 2 stack items
  BOp 'ADD', (s, r, l) -> s.push(l + r)            # sum
  BOp 'SUB', (s, r, l) -> s.push(l - r)            # difference
  BOp 'MUL', (s, r, l) -> s.push(l * r)            # product
  BOp 'DIV', (s, r, l) -> s.push(l / r)            # division
  BOp 'MOD', (s, r, l) -> s.push(l % r)            # modulo
  BOp 'SHL', (s, r, l) ->  s.push(l << r)          # left shift
  BOp 'SAR', (s, r, l) -> s.push(l >> r)           # right shift
  BOp 'SHR', (s, r, l) -> s.push(l >>> r)          # unsigned right shift
  BOp 'OR', (s, r, l) -> s.push(l | r)             # bitwise OR
  BOp 'AND', (s, r, l) -> s.push(l & r)            # bitwise AND
  BOp 'XOR', (s, r, l) -> s.push(l ^ r)            # bitwise XOR
  # tests
  BOp 'CEQ', (s, r, l) -> s.push(`l == r`)         # equals
  BOp 'CNEQ', (s, r, l) -> s.push(`l != r`)        # not equals
  BOp 'CID', (s, r, l) -> s.push(l == r)           # same
  BOp 'CNID', (s, r, l) -> s.push(l != r)          # not same
  BOp 'LT', (s, r, l) -> s.push(l < r)             # less than
  BOp 'LTE', (s, r, l) -> s.push(l <= r)           # less or equal than
  BOp 'GT', (s, r, l) -> s.push(l > r)             # greater than
  BOp 'GTE', (s, r, l) -> s.push(l >= r)           # greater or equal than
  BOp 'IN', (s, r, l) -> s.push(l of r)            # contains property
  BOp 'INSOF', (s, r, l) -> s.push(l instanceof r) # instance of

  # 1-arg opcodes
  Op 'SAVE', 1, (s, name) -> s.save(name, s.pop()) # save on reference
  Op 'LOAD', 1, (s, name) -> s.push(s.load(name))  # load from reference
  Op 'LITERAL', 1, (s, value) -> s.push(value)     # push literal value
]

(->
  # associate each opcode with its name
  for opcode in opcodes
    do (opcode) ->
      opcodes[opcode::name] = (script, args...) ->
        script.push(new opcode(args))
)()

module.exports = opcodes
