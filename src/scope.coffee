class Scope
  constructor: ->
    @keys = {}

  get: (key) -> @keys[key]

  set: (key, value) -> @keys[key] = value

module.exports = Scope
