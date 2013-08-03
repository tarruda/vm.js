Scope = require '../src/scope'

class Fiber
  constructor: (@scope)->
    @ip = 0
    @stack = new OperandStack(127)

  jump: (to) -> @ip = to

  # stack wrappers
  pop: -> @stack.pop()

  popn: (n) -> @stack.popn(n)

  top: -> @stack.top()

  dup: -> @stack.dup()

  dup2: -> @stack.dup2()

  swap: -> @stack.swap()

  push: (item) -> @stack.push(item)

  pushScope: -> @stack.push(@scope)

  save: -> @stack.save()

  save2: -> @stack.save2()

  load: -> @stack.load()

  load2: -> @stack.load2()
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
    @slot1 = null
    @slot2 = null

  save: -> @slot1 = @pop()

  save2: -> @slot1 = @pop(); @slot2 = @pop()

  load: -> @push(@slot1)

  load2: -> @push(@slot2); @push(@slot1)

  dup: -> @push(@array[@idx - 1])

  dup2: -> @push(@array[@idx - 2]); @push(@array[@idx - 2])

  swap: -> top = @pop(); bot = @pop(); @push(top); @push(bot)

  push: (item) -> @array[@idx++] = item

  pop: -> @array[--@idx]


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
