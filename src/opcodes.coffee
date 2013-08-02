Opcode = (->
  id = 0
  classFactory = (name, fn) ->
    OpcodeClass = (->
      # this is ugly but its the only way to get nice opcode
      # names when debugging with google chrome(since we are generating
      # the opcode classes)
      constructor = eval "(function #{name}(args) { this.args = args; })"
      # constructor = (@args) ->
      constructor::id = id++
      constructor::name = name
      constructor::exec = fn
      return constructor
    )()
    return OpcodeClass
  return classFactory
)()

opcodes = [
  Opcode 'DUP', (s) ->
    s.push(s.top())                 # duplicate top of stack
  Opcode 'ADD', (s) ->
    right = s.pop(); left = s.pop() # pop left and right operands
    s.push(left + right)            # push sum
  Opcode 'SUB', (s) ->
    right = s.pop(); left = s.pop() # pop left and right operands
    s.push(left - right)            # push subtract
  Opcode 'MUL', (s) ->
    right = s.pop(); left = s.pop() # pop left and right operands
    s.push(left * right)            # push multiplication
  Opcode 'DIV', (s) ->
    right = s.pop(); left = s.pop() # pop left and right operands
    s.push(left / right)            # push division
  Opcode 'SAVE', (s) ->
    s.save(@args[0], s.pop())       # save on scope chain
  Opcode 'LOAD', (s) ->
    s.push(s.load(@args[0]))        # load from scope chain
  Opcode 'LITERAL', (s) ->
    s.push(@args[0])                # push literal value
]

(->
  # associate each opcode with its name
  for opcode in opcodes
    do (opcode) ->
      opcodes[opcode::name] = (script, args...) ->
        script.push(new opcode(args))
)()

module.exports = opcodes
