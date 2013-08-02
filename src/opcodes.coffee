Opcode = (->
  # opcode id, correspond to the index in the opcodes array and is used
  # to represent serialized opcodes
  id = 0

  classFactory = (name, argc, fn) ->
    OpcodeClass = (->
      # this is ugly but its the only way to get nice opcode
      # names when debugging with google chrome(since we are generating
      # the opcode classes)
      constructor = eval "(function #{name}(args) { this.args = args; })"
      # constructor = (@args) ->
      constructor::id = id++
      constructor::name = name
      if typeof argc == 'function'
        constructor::exec = argc
        constructor::argc = 0
      else
        constructor::exec = fn
        constructor::argc = argc
      return constructor
    )()
    return OpcodeClass
  return classFactory
)()

opcodes = [
  Opcode 'SWAP', (s) ->             # swap the top of stack with the
    bottom = s.pop(); top = s.pop() # item below
    s.push(bottom); s.push(top)
  Opcode 'DUP', (s) ->              # duplicate top of stack
    s.push(s.top())
  Opcode 'ADD', (s) ->              # pop right and left operands and
    right = s.pop(); left = s.pop() # push the sum
    s.push(left + right)
  Opcode 'SUB', (s) ->              # pop right and left operands and
    right = s.pop(); left = s.pop() # push the difference
    s.push(left - right)
  Opcode 'MUL', (s) ->              # pop right and left operands and
    right = s.pop(); left = s.pop() # push the product
    s.push(left * right)
  Opcode 'DIV', (s) ->              # pop right and left operands and
    right = s.pop(); left = s.pop() # push the division
    s.push(left / right)
  Opcode 'SAVE', 1, (s) ->          # save on reference
    s.save(@args[0], s.pop())
  Opcode 'LOAD', 1, (s) ->          # load from reference
    s.push(s.load(@args[0]))
  Opcode 'LITERAL', 1, (s) ->       # push literal value
    s.push(@args[0])
]

(->
  # associate each opcode with its name
  for opcode in opcodes
    do (opcode) ->
      opcodes[opcode::name] = (script, args...) ->
        script.push(new opcode(args))
)()

module.exports = opcodes
