class Scope
  constructor: ->
    @keys = {}
    @saved = null

  get: (key) -> @keys[key]

  set: (key, value) -> @keys[key] = value

  save: (@saved) ->

  load: -> @saved

module.exports = Scope
