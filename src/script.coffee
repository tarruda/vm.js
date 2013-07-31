class Script
  constructor: ->
    @codes = []

  push: (fn) -> @codes.push(fn)


module.exports = Script
