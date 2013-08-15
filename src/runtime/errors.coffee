class VmError
  constructor: (@msg) ->

  toString: ->
    errName = @constructor.name
    if errName
      errName = errName.slice(2) # Remove the 'Vm' prefix
    else
      errName = 'Error'
    rv = "#{errName}: #{@msg}"
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
