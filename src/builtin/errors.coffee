class VmError
  constructor: (@msg) ->

class VmTypeError extends VmError


StopIteration = new VmError()

exports.VmError = VmError
exports.VmTypeError = VmTypeError
exports.StopIteration = StopIteration
