opcodes = require './opcodes'

class Script
  constructor: ->
    @instructions = []
    @loops = []
    @blocks = []
    @scripts = []
    @params = []
    @vars = {}
    @rest = null

  addParam: (param) -> @params.add(param)

  setRest: (name) -> @rest = name

  addScript: (script) -> @scripts.push(script); return @scripts.length - 1

  pushLoop: (labels) -> @loops.push(labels)

  popLoop: (labels) -> @loops.pop()

  pushBlock: -> @blocks.push(new Block(this))

  popBlock: -> @blocks.pop().popScope()

  createScope: -> @blocks[@blocks.length - 1].pushScope()

  declareVar: (name) -> @vars[name] = null

  declareFunction: (name, index) ->
    # declaring a function is nothing but assigning it to a name
    # at the beginning of the script
    codes = [
      new opcodes.FUNCTION([index])
      new opcodes.SCOPE([])
      new opcodes.LITERAL([name])
      new opcodes.SET([])
    ]
    @instructions = codes.concat(@instructions)

  loopStart: -> @loops[@loops.length - 1].start

  loopEnd: -> @loops[@loops.length - 1].end

  popInstruction: -> @instructions.pop()

  label: -> new Label(this)

  end: ->
    for code in @instructions
      code.normalizeLabels()
    if !(@instructions[@instructions.length - 1] instanceof opcodes.RET)
      this.RET()

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
      opcodes[opcode::name] = opcode
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
