Opcode = (->
  id = 0
  classFactory = (name, fn) ->
    OpcodeClass = (->
      # this is ugly but its the only way to get nicde opcode
      # names when inspecting with google chrome
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
  Opcode 'dup', (s) ->
    s.push(s.top())                 # duplicate top of stack
  Opcode 'add', (s) ->
    right = s.pop(); left = s.pop() # pop left and right operands
    s.push(left + right)            # push sum
  Opcode 'sub', (s) ->
    right = s.pop(); left = s.pop() # pop left and right operands
    s.push(left - right)            # push subtract
  Opcode 'mul', (s) ->
    right = s.pop(); left = s.pop() # pop left and right operands
    s.push(left * right)            # push multiplication
  Opcode 'div', (s) ->
    right = s.pop(); left = s.pop() # pop left and right operands
    s.push(left / right)            # push division
  Opcode 'save', (s) ->
    s.save(@args[0], s.pop())       # save on scope chain
  Opcode 'load', (s) ->
    s.push(s.load(@args[0]))        # load from scope chain
  Opcode 'literal', (s) ->
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
