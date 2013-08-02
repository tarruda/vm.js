# Quick and dirty object to keep track of execution state
class State
  constructor: (locals)->
    @stack = new Stack()
    @locals = locals || {} # local variables

  get: (object, key) ->
    (object || @locals)[key]

  set: (object, key, value) ->
    (object || @locals)[key] = value
    @stack.push(value)

  save: (key, value) -> @locals[key] = value

  load: (key) -> @locals[key]

  pop: -> @stack.pop()

  splice: (n) -> @stack.popn(n)

  top: -> @stack.top()

  dup2: -> @stack.dup2()

  push: (item) -> @stack.push(item)

  pushs: -> @stack.push(@locals)

class Stack
  constructor: ->
    @array = new Array(127)
    @idx = 0

  push: (item) -> @array[@idx++] = item

  pop: -> @array[--@idx]

  dup2: ->
    @array[@idx] = @array[@idx - 2]
    @array[@idx + 1] = @array[@idx - 1]
    @idx += 2

  popn: (n) ->
    rv = []
    while n--
      rv.push(@array[--@idx])
    return rv

  top: -> @array[@idx - 1]

  inspect: ->
    rv = []; i = @idx
    while i--
      rv.push(@array[i].toString())
    return rv.reverse().join(', ')


module.exports = State
