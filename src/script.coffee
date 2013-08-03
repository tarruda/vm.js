class Script
  constructor: ->
    @codes = []
    @labels = []
    @loops = []

  push: (fn) -> @codes.push(fn)

  pushLoop: (labels) -> @loops.push(labels)

  enclosingStart: -> @loops[@loops.length - 1].start

  enclosingEnd: -> @loops[@loops.length - 1].end

  label: -> new Label(this)

class Label
  constructor: (@script) ->
    @ip = null

  mark: -> @ip = @script.codes.length

exports.Script = Script
exports.Label = Label
