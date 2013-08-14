# Based on the ECMAScript specification document
#
# This module defines the data types that may be created and manipulated
# by scripts running in a Vm instance
{ArrayIterator} = require './util'
{VmTypeError} = require './errors'


class VmProperty
  constructor: (@enumerable, @configurable) ->


class VmDataProperty extends VmProperty
  constructor: (@writable, enumerable, configurable) ->
    super(enumerable, configurable)


class VmAccessorProperty extends VmProperty
  constructor: (@getter, @setter, enumerable, configurable) ->
    super(enumerable, configurable)


class VmObject
  constructor: (@proto, @container, @extensible = true) ->

  isExtensible: -> @extensible

  preventExtensions: -> @extensible = false; return true

  hasOwnProperty: (key) -> key of @container

  getOwnProperty: (key) -> @container[key]

  setOwnProperty: (key, value) -> @container[key] = value

  delOwnProperty: (key) -> delete @container[key]

  searchProperty: (key) ->
    obj = this
    while obj and not (prop = obj.getOwnProperty(key))
      obj = obj.proto
    if obj
      return prop
    return undefined

  hasProperty: (key) -> @searchProperty(key) != null

  get: (key, target = this) ->
    property = @searchProperty(key)
    if property is null
      return undefined
    if property instanceof VmAccessorProperty
      return property.get.call(target, key)
    if property instanceof VmProperty
      return property.value
    return property

  set: (key, value, target = this) ->
    property = @getOwnProperty(key)
    if property instanceof VmAccessorProperty
      if property.set
        property.set.call(target, key, value)
        return true
      else
        return false
    if property instanceof VmDataProperty
      if property.writable
        property.value = value
        return true
      else
        return false
    if property == undefined and not @isExtensible()
      return false
    @setOwnProperty(key, value)
    return true

  del: (key) ->
    if not @hasOwnProperty(key)
      return false
    property = @getOwnProperty(key)
    if property instanceof VmProperty and not property.configurable
      return false
    @delOwnProperty(key)
    return true

  defineOwnProperty: (key, property) ->
    if not @isExtensible()
      return false
    @setOwnProperty(key, property)
    return true

  isEnumerable: (k) ->
    v = @container[k]
    return not (v instanceof VmProperty) or v.enumerable

  enumerate: ->
    keys = []
    obj = this
    while obj
      keys = keys.concat(obj.ownKeys())
      obj = obj.proto
    return new ArrayIterator(keys)

  ownPropertiesKeys: -> new ArrayIterator(@ownKeys())

  ownKeys: ->
    keys = []
    for k of @container
      if @isEnumerable(k)
        keys.push(k)
    return keys


  unwrap: ->
    rv = {}
    for k, v of @container
      rv[k] = v
      if v instanceof VmObject
        rv[k] = v.unwrap()
    return rv

  invoke: (frame, key, length) ->
    fiber = frame.fiber
    func = @get(key)
    if func instanceof VmFunction
      return frame.call(length, func, this)
    if func instanceof Function # native function
      return frame.call(length, func, @container)
    if not func?
      err = new VmTypeError("Object #{@container} has no method '#{key}'")
    else
      err = new VmTypeError(
        "Property '#{key}' of object #{@container} is not a function")
    fiber.error = err
    frame.paused = true


class VmFunction extends VmObject
  constructor: (@script, @parent) ->

exports.VmObject = VmObject
exports.VmFunction = VmFunction
