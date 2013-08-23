Visitor = require './visitor'

# very simple optimizer that folds constant primitive expressions in the AST
class ConstantFolder extends Visitor

  UnaryExpression: (node) ->
    node = super(node)
    if node.operator is '+'
      return node.argument
    if node.argument.type is 'Literal' and
    not (node.argument.value instanceof RegExp)
      if 'prefix' not of node or node.prefix
        result = eval("#{node.operator}(#{node.argument.raw})")
      else
        result = eval("(#{node.argument.raw})#{node.operator}")
      return {type: 'Literal', value: result, loc: node.loc}
    return node

  BinaryExpression: (node) ->
    node = super(node)
    if node.left.type is 'Literal' and node.right.type == 'Literal' and
    not (node.right.value instanceof RegExp) and
    not (node.left.value instanceof RegExp)
      result = eval("(#{node.left.raw} #{node.operator} #{node.right.raw})")
      return {type: 'Literal', value: result, loc: node.left.loc}
    return node


module.exports = ConstantFolder
