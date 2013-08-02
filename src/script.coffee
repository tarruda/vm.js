class Script
  constructor: ->
    @codes = []
    @labels = []

  push: (fn) -> @codes.push(fn)

  label: -> new Label(this)

class Label
  constructor: (@script) ->
    @ip = null

  mark: -> @ip = @script.codes.length

exports.Script = Script
exports.Label = Label
