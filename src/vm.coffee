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
    while fiber.ip < len
      rv = codes[fiber.ip++].exec(fiber)
    if (remaining = fiber.stack.idx) != 0
      throw new Error("operand stack still has #{remaining} after execution")
    return fiber.stack.load()


module.exports = Vm
