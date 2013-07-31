Script = require './script'

opcodes = {}

op = (id, args..., exec) ->
  OpCodeClass = opcodes[id]
  if !OpCodeClass
    class OpCodeClass
      constructor: (@args) ->
      exec: exec
    opcodes[id] = OpCodeClass
  return new OpCodeClass(args)

emit =
  Literal: (node, script) ->
    script.push op 'LIT', node.value, (state) ->
      state.push(@args[0])

  ExpressionStatement: (node, script) ->
    emit[node.expression.type](node.expression, script)

  BinaryExpression: (node, script) ->
    emit[node.left.type](node.left, script)      # push left expression
    emit[node.right.type](node.right, script)    # push init expression
    binary[node.operator](script)                # apply operator

  VariableDeclaraction: (node, script) ->
    for child in node.declarations
      emit[child.type](child.init, script)       # declare each variable

  VariableDeclarator: (node, script) ->
    emit[node.init.type](node.init, script)      # push init
    script.push op 'DECL', node.name, (state) -> # store on local context
      state.local(@args[0], state.pop())

binary =
  '+': (script) ->
    script.push op 'ADD', (state) ->
      right = state.pop(); left = state.pop()    # pop left and right operands
      state.push(left + right)                   # push sum
  '-': (script) ->
    script.push op 'SUB', (state) ->
      right = state.pop(); left = state.pop()    # pop left and right operands
      state.push(left - right)                   # push subtract
  '*': (script) ->
    script.push op 'MUL', (state) ->
      right = state.pop(); left = state.pop()    # pop left and right operands
      state.push(left * right)                   # push multiplication
  '/': (script) ->
    script.push op 'DIV', (state) ->
      right = state.pop(); left = state.pop()    # pop left and right operands
      state.push(left / right)                   # push division

initializeOpcodes = ->

compile = (node) ->
  script = new Script()
  for child in node.body
    emit[child.type](child, script)
  script

module.exports = compile

