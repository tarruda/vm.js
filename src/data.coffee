class BuiltinObject

class Closure extends BuiltinObject
  constructor: (@script, @parent) ->

class Scope extends BuiltinObject
  constructor: (@parent, @vars) ->
    @keys = {}

  get: (key) ->
    rv = @keys[key]
    if rv == undefined
      return @parent.get(key)
    return rv

  set: (key, value) ->
    if !@vars || key of @vars || key == 'arguments'
      @keys[key] = value
      return
    @parent.set(key, value)

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

  remaining: -> @idx


exports.Closure = Closure
exports.Scope = Scope
exports.OperandStack = OperandStack
