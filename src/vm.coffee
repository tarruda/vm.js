esprima = require 'esprima'

State = require './state'
compile = require './opcode_compiler'

class Vm
  eval: (string, scope) ->
    ast = esprima.parse(string)
    script = compile(ast)
    state = new State(scope)
    codes = script.codes # array of opcodes
    len = codes.length   # total length
    ip = 0        # instruction pointer
    while ip < len
      rv = codes[ip++].exec(state)
    return state.pop()


module.exports = Vm
