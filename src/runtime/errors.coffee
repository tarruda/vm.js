class VmError
  constructor: (@message) ->

  toString: ->
    errName = @constructor.display
    rv = "#{errName}: #{@message}"
    if @trace
      for frame in @trace
        l = frame.line
        c = frame.column
        name = frame.at.name
        filename = frame.at.filename
        if name
          rv += "\n    at #{name} (#{filename}:#{l}:#{c})"
        else
          rv += "\n    at #{filename}:#{l}:#{c}"
    return rv


class VmEvalError extends VmError
  @display: 'EvalError'


class VmRangeError extends VmError
  @display: 'RangeError'


class VmReferenceError extends VmError
  @display: 'ReferenceError'


class VmSyntaxError extends VmError
  @display: 'SyntaxError'


class VmTypeError extends VmError
  @display: 'TypeError'


class VmURIError extends VmError
  @display: 'URIError'


class VmTimeoutError extends VmError
  @display: 'TimeoutError'

  constructor: (@fiber) ->
    super("Script timed out")


exports.VmError = VmError
exports.VmEvalError = VmEvalError
exports.VmRangeError = VmRangeError
exports.VmReferenceError = VmReferenceError
exports.VmSyntaxError = VmSyntaxError
exports.VmTypeError = VmTypeError
exports.VmURIError = VmURIError
exports.VmTimeoutError = VmTimeoutError
