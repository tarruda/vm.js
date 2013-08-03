opcodes = require './opcodes'

class Script
  constructor: ->
    @instructions = []
    @loops = []
    @blocks = []

  pushLoop: (labels) -> @loops.push(labels)

  popLoop: (labels) -> @loops.pop()

  pushBlock: -> @blocks.push(new Block(this))

  popBlock: -> @blocks.pop().popScope()

  createScope: -> @blocks[@blocks.length - 1].pushScope()

  declareVar: (name) ->

  loopStart: -> @loops[@loops.length - 1].start

  loopEnd: -> @loops[@loops.length - 1].end

  label: -> new Label(this)

class Block
  constructor: (@script) ->
    @newScope = false
    @index = @script.instructions.length

  pushScope: ->
    return if @newScope
    @newScope = true
    @script.instructions.splice(@index, 1, new opcodes.OPEN_SCOPE())

  popScope: ->
    return if !@newScope
    @script.instructions.push(new opcodes.CLOSE_SCOPE())

class Label
  constructor: (@script) ->
    @ip = null

  mark: -> @ip = @script.instructions.length

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
      Script::[opcode::name] = (args...) ->
        @instructions.push(new opcode(args))
)()

module.exports = Script
