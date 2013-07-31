# Encapsulates all state of script execution
class State
  constructor: ->
    @stack = [] # operand stack
    @locals = {} # local variables

  save: (key, value) -> @locals[key] = value

  load: (key) -> @locals[key]

  pop: -> @stack.pop()

  push: (value) -> @stack.push(value)


module.exports = State
