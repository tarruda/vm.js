opcodes = require './opcodes'


# convert compiled scripts from/to json-compatible structure
scriptToJson = (script) ->
  rv = [
    script.filename or 0
    script.name or 0
    instructionsToJson(script.instructions)
    []
    script.localNames
    []
    script.stackSize
    script.strings
    []
  ]
  for s in script.scripts
    rv[3].push(scriptToJson(s))
  for guard in script.guards
    rv[5].push([
      guard.start or -1
      guard.handler or -1
      guard.finalizer or -1
      guard.end or -1
    ])
  for regexp in script.regexps
    rv[8].push(regexpToString(regexp))
  rv[9] = script.source or 0
  return rv


scriptFromJson = (json) ->
  filename = if json[0] != 0 then json[0] else null
  name = if json[1] != 0 then json[1] else null
  instructions = instructionsFromJson(json[2])
  scripts = []
  localNames = json[4]
  localLength = localNames.length
  guards = []
  stackSize = json[6]
  strings = json[7]
  regexps = []
  for s in json[3]
    scripts.push(scriptFromJson(s))
  for guard in json[5]
    guards.push({
      start: if guard[0] != -1 then guard[0] else null
      handler: if guard[1] != -1 then guard[1] else null
      finalizer: if guard[2] != -1 then guard[2] else null
      end: if guard[3] != -1 then guard[3] else null
    })
  for regexp in json[8]
    regexps.push(regexpFromString(regexp))
  source = if json[9] != 0 then json[9] else null
  return new Script(filename, name, instructions, scripts, localNames,
    localLength, guards, stackSize, strings, regexps, source)


instructionsToJson = (instructions) ->
  rv = []
  for inst in instructions
    code = [inst.id]
    if inst.args
      for a in inst.args
        if a?
          code.push(a)
        else
          code.push(null)
    rv.push(code)
  return rv


instructionsFromJson = (instructions) ->
  rv = []
  for inst in instructions
    klass = opcodes[inst[0]]
    args = []
    for i in [1...inst.length]
      args.push(inst[i])
    opcode = new klass(if args.length then args else null)
    rv.push(opcode)
  return rv


regexpToString = (regexp) ->
  rv = regexp.source + '/'
  rv += if regexp.global then 'g' else ''
  rv += if regexp.ignoreCase then 'i' else ''
  rv += if regexp.multiline then 'm' else ''
  return rv


regexpFromString = (str) ->
  sliceIdx = str.lastIndexOf('/')
  source = str.slice(0, sliceIdx)
  flags = str.slice(sliceIdx + 1)
  return new RegExp(source, flags)


class Script
  constructor: (@filename, @name,  @instructions, @scripts, @localNames,
  @localLength, @guards, @stackSize, @strings, @regexps, @source) ->

  toJSON: -> scriptToJson(this)

  @fromJSON: scriptFromJson

  @regexpToString: regexpToString


module.exports = Script
