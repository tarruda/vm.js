esprima = require 'esprima'

opcodes = require './opcodes'
ConstantFolder = require './constant_folder'
Normalizer = require './normalizer'
Emitter = require './emitter'

class Compiler
  constructor: (@visitors...) ->

  compile: (node) ->
    node = esprima.parse(node, loc: false)
    for visitor in @visitors
      node = visitor.visit(node)
    emitter = new Emitter()
    emitter.visit(node)
    return emitter.end()


module.exports = (code) ->
  compiler = new Compiler(new ConstantFolder(), new Normalizer())
  return compiler.compile(code)
