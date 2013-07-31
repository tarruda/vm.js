# Encapsulates all state of script execution
class State
  constructor: ->
    @stack = [] # operand stack
    @locals = {} # local variables

  local: (key, value) -> value if (@locals[key] = value) else @locals[key]

  pop: -> @stack.pop()

  push: (value) -> @stack.push(value)


module.exports = State
