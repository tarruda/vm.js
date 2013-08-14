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
    super(opts.proto, opts.object)
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


exports.ArrayIterator = ArrayIterator
exports.NativeProxy = NativeProxy
