class BuiltinObject

class VmFunction extends BuiltinObject
  constructor: (@script, @parent) ->

exports.VmFunction = VmFunction
