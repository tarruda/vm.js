class VmError
  constructor: (@msg) ->

class VmEvalError extends VmError

class VmRangeError extends VmError

class VmReferenceError extends VmError

class VmSyntaxError extends VmError

class VmTypeError extends VmError

class VmURIError extends VmError


exports.VmError = VmError
exports.VmEvalError = VmEvalError
exports.VmRangeError = VmRangeError
exports.VmReferenceError = VmReferenceError
exports.VmSyntaxError = VmSyntaxError
exports.VmTypeError = VmTypeError
exports.VmURIError = VmURIError
