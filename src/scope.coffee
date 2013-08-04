class Scope
  constructor: (@parent, @vars) ->
    @keys = {}

  get: (key) ->
    rv = @keys[key]
    if rv == undefined
      return @parent.get(key)
    return rv

  set: (key, value) ->
    if !@vars || key of @vars
      @keys[key] = value
      return
    @parent.set(key, value)


module.exports = Scope
