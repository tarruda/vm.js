Scope = require '../src/scope'

class Fiber
  constructor: (@scope)->
    @stack = new OperandStack(127)

  # stack wrappers
  pop: -> @stack.pop()

  popn: (n) -> @stack.popn(n)

  top: -> @stack.top()

  dup2: -> @stack.dup2()

  push: (item) -> @stack.push(item)

  pushs: -> @stack.push(@scope)
  #

  # scope wrappers
  save: -> @scope.save(@pop())
  #

  # object wrappers
  get: (object, key) ->
    if object instanceof Scope then object.get(key)
    else object[key]

  set: (object, key, value) ->
    if object instanceof Scope then object.set(key, value)
    else object[key] = value
    @stack.push(value)
  #

class OperandStack
  constructor: (size) ->
    @array = new Array(size)
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
      rv.push((@array[i].inspect || @array[i].toString)())
    return rv.reverse().join(', ')


module.exports = Fiber
