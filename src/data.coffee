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

exports.Closure = Closure
exports.Scope = Scope
