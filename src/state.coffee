# Encapsulates all state of script execution
class State
  constructor: (locals)->
    @stack = [] # operand stack
    @locals = locals || {} # local variables

  save: (key, value) -> @locals[key] = value

  load: (key) -> @locals[key]

  pop: -> @stack.pop()

  top: -> @stack[@stack.length - 1]

  push: (value) -> @stack.push(value)


module.exports = State
