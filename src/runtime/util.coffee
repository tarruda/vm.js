toStr = (obj) -> Object.prototype.toString.call(obj)


# thanks john resig: http://ejohn.org/blog/objectgetprototypeof/
if typeof Object.getPrototypeOf != 'function'
  if typeof ''.__proto__ == 'object'
    prototypeOf = (obj) -> obj.__proto__
  else
    prototypeOf = (obj) -> obj.constructor.prototype
else
  prototypeOf = Object.getPrototypeOf

if typeof Object.create != 'function'
  create = ( ->
    F = ->
    return (o) ->
      if arguments.length != 1
        throw new Error(
          'Object.create implementation only accepts one parameter.')
      F.prototype = o
      return new F()
  )()
else
  create = Object.create

hasProp = (obj, prop) ->
  Object.prototype.hasOwnProperty.call(obj, prop)

if typeof Array.isArray != 'function'
  isArray = (obj) -> toStr(obj) == '[object Array]'
else
  isArray = Array.isArray

exports.prototypeOf = prototypeOf
exports.create = create
exports.hasProp = hasProp
exports.isArray = isArray
