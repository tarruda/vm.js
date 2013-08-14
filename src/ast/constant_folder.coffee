AstVisitor = require './visitor'

# very simple optimizer that folds constant expressions in the AST
class ConstantFolder extends AstVisitor

  UnaryExpression: (node) ->
    node = super(node)
    if node.operator is '+'
      return node.argument
    if node.argument.type is 'Literal'
      if node.prefix
        result = eval("#{node.operator}#{node.argument.raw}")
      else
        result = eval("#{node.argument.raw}#{node.operator}")
      return {type: 'Literal', value: result, loc: node.loc}
    return node

  BinaryExpression: (node) ->
    node = super(node)
    if node.left.type is 'Literal' and node.right.type == 'Literal'
      result = eval("#{node.left.raw} #{node.operator} #{node.right.raw}")
      return {type: 'Literal', value: result, loc: node.left.loc}
    return node


module.exports = ConstantFolder
