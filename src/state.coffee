# Quick and dirty object to keep track of execution state
class State
  constructor: (locals)->
    @stack = [] # operand stack
    @locals = locals || {} # local variables

  save: (key, value) -> @locals[key] = value

  load: (key) -> @locals[key]

  pop: -> @stack.pop()

  splice: (n) -> @stack.splice(@stack.length - n, n).reverse()

  top: -> @stack[@stack.length - 1]

  push: (value) -> @stack.push(value)


module.exports = State
