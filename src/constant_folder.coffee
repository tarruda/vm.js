
class ConstantFolder

  BinaryExpression: (node) ->
    if node.left.type == 'Literal' && node.right.type == 'Literal'
      result = eval("#{node.left.raw} #{node.operator} #{node.right.raw}")
      return {value: result, type: 'Literal'}
    return node


module.exports = ConstantFolder
