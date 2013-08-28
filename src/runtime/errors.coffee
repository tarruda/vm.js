{isArray} = require './util'

printTrace = (trace, indent = '') ->
  indent += '    '
  rv = ''
  for frame in trace
    if isArray(frame)
      rv += "\n\n#{indent}Rethrown:"
      rv += printTrace(frame, indent)
      continue
    l = frame.line
    c = frame.column
    name = frame.at.name
    filename = frame.at.filename
    if name
      rv += "\n#{indent}at #{name} (#{filename}:#{l}:#{c})"
    else
      rv += "\n#{indent}at #{filename}:#{l}:#{c}"
  return rv

class VmError
  constructor: (@message) ->
    trace = null

  toString: ->
    errName = @constructor.display
    rv = "#{errName}: #{@message}"
    if @trace
      rv += printTrace(@trace)
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


