esprima = require 'esprima'

Fiber = require './fiber'
compile = require './opcode_compiler'

class Vm
  eval: (string, scope) ->
    ast = esprima.parse(string)
    script = compile(ast)
    fiber = new Fiber(scope)
    instructions = script.instructions # array of opcodes
    len = instructions.length   # total length
    while fiber.ip < len
      rv = instructions[fiber.ip++].exec(fiber)
    if (remaining = fiber.stack.idx) != 0
      throw new Error("operand stack still has #{remaining} after execution")
    return fiber.stack.load()


module.exports = Vm
