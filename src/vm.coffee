esprima = require 'esprima'

Fiber = require './fiber'
compile = require './opcode_compiler'

class Vm
  eval: (string, scope) ->
    ast = esprima.parse(string)
    script = compile(ast)
    fiber = new Fiber(scope)
    codes = script.codes # array of opcodes
    len = codes.length   # total length
    ip = 0        # instruction pointer
    while ip < len
      rv = codes[ip++].exec(fiber)
    if fiber.stack.idx != 0
      throw new Error('operand stack still has items after execution')
    return scope.load()


module.exports = Vm
