{VmObject} = require './internal'
{ArrayIterator} = require './util'


# Data manipulated by code in the VM can be classified in two groups:
# - VmObject instances(for implementing runtime stuff like proxies, getters,
#   and setters)
# - Native objects(any object or primitive from the host vm)
#
# There are two ways code inside the VM can reach native objects:
# - The object was created inside the VM(eg: literals)
# - The object was provided by the global object
#
# Since the VM is already running inside a working javascript environment,
# we'll be smart and skip reimplementing basic builtin objects like Array,
# String, JSON... which are very likely to already exist in the host global
# object.
#
# The problem is that we need to expose these builtin objects to the VM
# global object, and letting vm code modify globals outside its context
# those is not an option if we want to have sandboxing capabilities. (This
# also applies to objects we implement to polyfill missing features like
# JSON for very old browsers)
#
# So here we have the NativeProxy class which solves two problems:
#
# - It lets sandboxed code to safely read/write builtin objects properties
#   from the host vm without touching the real object behind the proxy
# - It provides builtin objects with properties that are only visible
#   inside the vm(polyfilling things from harmony like the 'iterator'
#   property on array prototype)
#
# This is acomplished by making NativeProxy implement the VmObject interface
# (for most purposes, it will behave like a normal VmObject) and by keeping
# the builtin object state using a simple copy-on-write method(save
# modifications on a separate object instead of directly modifying the builtin)
#
# Not only this provides each Vm instance with its own isolated copy of the
# global object, it also let us safely run untrusted code inside the vm.
class NativeProxy extends VmObject
  constructor: (opts) ->
    super(null, opts.object)
    # included properties
    @include = opts.include or {}
    # excluded properties
    @exclude = opts.exclude or {}

  hasOwnProperty: (key) ->
    (key of @container and not key of @exclude) or key of @include

  getOwnProperty: (key) ->
    if key of @include
      return @include[key]
    if key of @container and key not of @exclude
      return @container[key]
    return undefined

  setOwnProperty: (key, value) ->
    if key of @exclude
      delete @exclude[key]
    if value != @container[key]
      @include[key] = value

  delOwnProperty: (key) ->
    if key of @include
      delete @include[key]
    @exclude[key] = null

  get: (key, target = @container) -> super(key, target)

  set: (key, value, target = @container) -> super(key, value, target)

  isEnumerable: (k, v) ->
    if k of @exclude
      return false
    return not (v instanceof VmProperty) or v.enumerable

  ownKeys: ->
    keys = super()
    for k of @include
      if k not in keys
        keys.push(k)
    return keys


nativeBuiltins = [
  Object
  Object.prototype
  Object.prototype.isPrototypeOf
  Function
  Function.prototype
  Function.prototype.apply
  Function.prototype.call
  Function.prototype.toString
  Number
  Number.isNaN
  Number.isFinite
  Number.prototype
  Number.prototype.toExponential
  Number.prototype.toFixed
  Number.prototype.toLocaleString
  Number.prototype.toPrecision
  Number.prototype.toString
  Number.prototype.valueOf
  Boolean
  Boolean.prototype
  Boolean.prototype.toString
  Boolean.prototype.valueOf
  String
  String.fromCharCode
  String.prototype
  String.prototype.charAt
  String.prototype.charCodeAt
  String.prototype.concat
  String.prototype.contains
  String.prototype.indexOf
  String.prototype.lastIndexOf
  String.prototype.match
  String.prototype.replace
  String.prototype.search
  String.prototype.slice
  String.prototype.split
  String.prototype.substr
  String.prototype.substring
  String.prototype.toLowerCase
  String.prototype.toString
  String.prototype.toUpperCase
  String.prototype.valueOf
  Array
  Array.isArray
  Array.every
  Array.prototype
  Array.prototype.join
  Array.prototype.reverse
  Array.prototype.sort
  Array.prototype.push
  Array.prototype.pop
  Array.prototype.shift
  Array.prototype.unshift
  Array.prototype.splice
  Array.prototype.concat
  Array.prototype.slice
  Array.prototype.indexOf
  Array.prototype.lastIndexOf
  Array.prototype.forEach
  Array.prototype.map
  Array.prototype.reduce
  Array.prototype.reduceRight
  Array.prototype.filter
  Array.prototype.some
  Array.prototype.every
  Date
  Date.now
  Date.parse
  Date.UTC
  Date.prototype
  Date.prototype.getDate
  Date.prototype.getDay
  Date.prototype.getFullYear
  Date.prototype.getHours
  Date.prototype.getMilliseconds
  Date.prototype.getMinutes
  Date.prototype.getMonth
  Date.prototype.getSeconds
  Date.prototype.getTime
  Date.prototype.getTimezoneOffset
  Date.prototype.getUTCDate
  Date.prototype.getUTCDay
  Date.prototype.getUTCFullYear
  Date.prototype.getUTCHours
  Date.prototype.getUTCMilliseconds
  Date.prototype.getUTCMinutes
  Date.prototype.getUTCSeconds
  Date.prototype.setDate
  Date.prototype.setFullYear
  Date.prototype.setHours
  Date.prototype.setMilliseconds
  Date.prototype.setMinutes
  Date.prototype.setMonth
  Date.prototype.setSeconds
  Date.prototype.setUTCDate
  Date.prototype.setUTCDay
  Date.prototype.setUTCFullYear
  Date.prototype.setUTCHours
  Date.prototype.setUTCMilliseconds
  Date.prototype.setUTCMinutes
  Date.prototype.setUTCSeconds
  Date.prototype.toDateString
  Date.prototype.toISOString
  Date.prototype.toJSON
  Date.prototype.toLocaleDateString
  Date.prototype.toLocaleString
  Date.prototype.toLocaleTimeString
  Date.prototype.toString
  Date.prototype.toTimeString
  Date.prototype.toUTCString
  Date.prototype.valueOf
  RegExp
  RegExp.prototype
  RegExp.prototype.exec
  RegExp.prototype.test
  RegExp.prototype.toString
  Math
  Math.abs
  Math.acos
  Math.asin
  Math.atan
  Math.atan2
  Math.ceil
  Math.cos
  Math.exp
  Math.floor
  Math.imul
  Math.log
  Math.max
  Math.min
  Math.pow
  Math.random
  Math.round
  Math.sin
  Math.sqrt
  Math.tan
  JSON
  JSON.parse
  JSON.stringify
]


# Every builtin object exposed by the VM must have a unique id so the runtime
# can quickly decide whether an object is a builtin object and retrieve
# the NativeProxy instance associated with it. Modifying global objects is not
# pretty but I couldn't figure out a better way to do this(unless there's
# a way to have hashtables with object references as keys)
(->
  i = 0
  for builtin in nativeBuiltins
    if builtin
      builtin.__mdid__ = i
    i++
)()


exports.ArrayIterator = ArrayIterator
exports.NativeProxy = NativeProxy
exports.nativeBuiltins = nativeBuiltins
