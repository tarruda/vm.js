Script = require './script'

Opcode = (->
  id = 0
  classFactory = (name, fn) ->
    OpcodeClass = (->
      # this is ugly but its the only way to get meaningful opcode
      # names when inspecting with google chrome
      constructor = eval "(function #{name}(args) { this.args = args; })"
      constructor::id = id++
      constructor::name = name
      constructor::exec = fn
      return constructor
    )()
    return OpcodeClass
  return classFactory
)()

opcodes = [
  Opcode 'literal', (s) ->
    s.push(@args[0])                   # push literal value
  Opcode 'add', (s) ->
    right = s.pop(); left = s.pop()    # pop left and right operands
    s.push(left + right)               # push sum
  Opcode 'sub', (s) ->
    right = s.pop(); left = s.pop()    # pop left and right operands
    s.push(left - right)               # push subtract
  Opcode 'mul', (s) ->
    right = s.pop(); left = s.pop()    # pop left and right operands
    s.push(left * right)               # push multiplication
  Opcode 'div', (s) ->
    right = s.pop(); left = s.pop()    # pop left and right operands
    s.push(left / right)               # push division
  Opcode 'save', (s) ->
    s.save(@args[0], s.pop())         # store on local scope
]

(->
  # associate each opcode with its name
  for opcode in opcodes
    do (opcode) -> opcodes[opcode::name] = (args...) -> new opcode(args)
)()

binaryOp =
  '+': opcodes.add
  '-': opcodes.sub
  '*': opcodes.mul
  '/': opcodes.div

emit =
  Literal: (node, script) -> script.push opcodes.literal(node.value)

  ExpressionStatement: (node, script) ->
    emit[node.expression.type](node.expression, script)

  BinaryExpression: (node, script) ->
    emit[node.left.type](node.left, script)      # emit left expression
    emit[node.right.type](node.right, script)    # emit right expression
    script.push binaryOp[node.operator]()        # emit binary opcode

  VariableDeclaraction: (node, script) ->
    for child in node.declarations
      emit[child.type](child.init, script)       # declare each variable

  VariableDeclarator: (node, script) ->
    emit[node.init.type](node.init, script)      # emit init expression
    script.push opcodes.store(node.name)         # emit store opcode

compile = (node) ->
  script = new Script()
  for child in node.body
    emit[child.type](child, script)
  script

module.exports = compile

