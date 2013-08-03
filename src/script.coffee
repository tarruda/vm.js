opcodes = require './opcodes'

class Script
  constructor: ->
    @codes = []
    @labels = []
    @loops = []

  pushLoop: (labels) -> @loops.push(labels)

  popLoop: (labels) -> @loops.pop()

  enclosingStart: -> @loops[@loops.length - 1].start

  enclosingEnd: -> @loops[@loops.length - 1].end

  label: -> new Label(this)

class Label
  constructor: (@script) ->
    @ip = null

  mark: -> @ip = @script.codes.length

(->
  # create a Script method for each opcode
  for opcode in opcodes
    do (opcode) ->
      # also add a method for resolving label addresses
      opcode::normalizeLabels = ->
        for i in [0...@argc]
          if @args[i] instanceof Label
            if @args[i].ip == null
              throw new Error('label has not been marked')
            # its a label, replace with the instruction pointer
            @args[i] = @args[i].ip
      Script::[opcode::name] = (args...) -> @codes.push(new opcode(args))
)()

module.exports = Script
