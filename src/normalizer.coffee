{parse} = require 'esprima'

AstVisitor = require './ast_visitor'

# Visitor that performs normalization of ast nodes that can be expressed as
# special cases or combination of other nodes
#
# The motivation of this visitor is to keep the Emitter implementation as
# simple as possible by only having to deal with a simplified AST
class Normalizer extends AstVisitor

  # Function normalization
  FunctionDeclaration: (node) ->
    node = @FunctionExpression(node)
    node.isExpression = false
    node.declare = node.id.name
    return node

  FunctionExpression: (node) ->
    node =
      loc: node.loc
      type: 'VmFunction'
      id: node.id
      params: node.params
      defaults: node.defaults
      rest: node.rest
      generator: node.generator
      expression: node.expression
      body: @visit(node.body)
      declare: false
      isExpression: true
    len = node.params.length
    if node.rest
      # initialize rest parameter
      declaration = parse("var #{node.rest.name};").body[0]
      rest = {type: 'VmRestParamInit', name: node.rest.name, index: len}
      node.body.body.unshift(@visit(declaration))
      node.body.body.unshift(rest)
    params = []
    for i in [0...len]
      param = node.params[i]
      def = node.defaults[i]
      if param.type != 'Identifier' then throw new Error('assert error')
      declaration = parse("var #{param.name} = arguments[#{i}] || 0;").body[0]
      declarator = declaration.declarations[0]
      if def then declarator.init.right = def
      else declarator.init = declarator.init.left
      params.push(@visit(declaration))
    node.body.body = params.concat(node.body.body)
    return node

  AssignmentExpression: (node) ->
    node = super(node)
    if node.left.type in ['ArrayPattern', 'ObjectPattern']
      load = {type: 'VmLoadExpression', name: '_destruct'}
      save = {type: 'VmSaveExpression', name: '_destruct', value: node.right}
      # translate destructuring assignment to a bunch of simple assignments
      destructuringAssignment =
        type: 'SequenceExpression'
        expressions: [save]
      if node.left.type == 'ArrayPattern'
        index = 0
        for element in node.left.elements
          if element
            # get the nth-item from the array
            childAssignment =
              operator: node.operator
              type: 'VmAssignmentExpression'
              left: element
              right:
                object: load
                type: 'MemberExpression'
                # omit the object since its already loaded on stack
                computed: true
                property: {type: 'Literal', value: index}
            destructuringAssignment.expressions.push(childAssignment)
          index++
      else
        for property in node.left.properties
          source = property.key
          target = property.value
          childAssignment =
            operator: node.operator
            type: 'VmAssignmentExpression'
            left: target
            right:
              object: load
              type: 'MemberExpression'
              # omit the object since its already loaded on stack
              computed: true
              property: {type: 'Literal', value: source.name}
          destructuringAssignment.expressions.push(childAssignment)
      destructuringAssignment.expressions.push(load)
      return destructuringAssignment
    vmAssign =
      type: 'VmAssignmentExpression'
      left: node.left
      right: node.right
      operator: node.operator
    if node.operator != '='
      vmAssign.right =
        type: 'BinaryExpression'
        operator: node.operator.slice(0, node.operator.length - 1)
        left: vmAssign.left
        right: node.right
      vmAssign.operator = '='
    return vmAssign

  UpdateExpression: (node) ->
    node = super(node)
    assignNode = @AssignmentExpression
      type: 'AssignmentExpression'
      operator: if node.operator == '++' then '+=' else '-='
      left: node.argument
      right: {type: 'Literal', value: 1}
    if !node.prefix
      assignNode =
        type: 'SequenceExpression'
        expressions: [
          {type: 'VmSaveExpression', name: '_update', value: node.argument}
          assignNode
          {type: 'VmLoadExpression', name: '_update'}
        ]
    return assignNode

  VariableDeclarator: (node) ->
    node = super(node)
    vmDeclare =
      type: 'BlockStatement'
      body: [{type: 'VmVariableDeclaration', name: node.id.name}]
    if node.init
      vmAssign =
        type: 'ExpressionStatement'
        expression:
          loc: node.loc
          type: 'VmAssignmentExpression'
          operator: '='
          left: node.id
          right: node.init
      vmDeclare.body.push(vmAssign)
    return vmDeclare

module.exports = Normalizer
