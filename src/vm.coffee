State = require './state'
compile = require './opcodes'

class Vm
  eval: (string) ->
    ast = esprima.parse(string)
    script = compile(ast)
    state = new State()
    codes = script.codes # array of opcodes
    len = codes.length   # total length
    ip = 0        # instruction pointer
    while ip < len
      rv = codes[ip++].exec(state)
    return state.pop()


module.exports = Vm
