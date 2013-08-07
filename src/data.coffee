class BuiltinObject

class Closure extends BuiltinObject
  constructor: (@script, @parent) ->

exports.Closure = Closure
