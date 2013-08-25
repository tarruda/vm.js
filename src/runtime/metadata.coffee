{ArrayIterator} = require './builtin'

# Vm instances will manipulate the same native objects created/modified
# by the host javascript engine.
#
# There are two ways code inside a Vm can reach native objects:
#
# - The object was created inside the Vm(eg: literals)
# - The object was injected to the global object
#
# Since the Vm is already running inside a working javascript engine,
# we'll be smart and skip reimplementing basic builtin objects like Array,
# String, JSON... which are very likely to already exist in the host's global
# object.
#
# The problem with that approach is: we need to expose these builtin objects to
# the Vm global object, and letting untrusted code modify globals outside its
# context is not an option if we want to have sandboxing capabilities. (This
# also applies to non-builtin objects that we need to have a per-Vm state)
#
# So here we have the *Metadata classes which solves a few problems:
#
# - It lets sandboxed code to safely read/write builtin objects properties
#   from the host Vm without touching the real object.
# - It provides builtin objects with properties that are only visible
#   inside the Vm(polyfilling things from harmony like the 'iterator'
#   property on array prototype)
# - It lets us implement things that may not be available to the host
#   javascript engine(eg: proxies or getters/setters)
#
# Here's how it works: Instances of the *Metadata classes contain state that
# is used by the runtime to determine the behavior of doing some kind of action
# with the object associated with it. For example, the metadata object
# associated with a native builtin can contain a list of deleted/modified
# properties, which will be considered only in the Realm of the Vm which
# deleted/modified those properties.
#
# There are two properties a Vm can use to retrieve the ObjectMetadata
# instance associated with an object:
#
# - __md__   : ObjectMetadata instance
# - __mdid__ : Id of the ObjectMetadata instance associated with it and stored
#              privately in the Realm associated with the Vm
#
# Each native builtin will have an __mdid__ property set when the first Realm
# is created, so each Vm instance will contain its own private state of
# builtins. Objects can also have an __md__ property will store its state
# inline(By default, non-builtin objects store only special properties that
# implement getters/setters or proxies).


class PropertyMetadata
  constructor: (@enumerable = true, @configurable = true) ->


class DataPropertyMetadata extends PropertyMetadata
  constructor: (@value, @writable, enumerable, configurable) ->
    super(enumerable, configurable)


class AccessorPropertyMetadata extends PropertyMetadata
  constructor: (@getter, @setter, enumerable, configurable) ->
    super(enumerable, configurable)


class ObjectMetadata
  constructor: (@object, @realm) ->
    @proto = null
    @properties = {}
    @extensible = true

  hasOwnProperty: (key) -> key of @properties or key of @object

  getOwnProperty: (key) -> @properties[key] or @object[key]

  setOwnProperty: (key, value) -> @object[key] = value

  delOwnProperty: (key) -> delete @properties[key] and delete @object[key]

  searchProperty: (key) ->
    md = this
    while md
      if md.hasOwnProperty(key)
        prop = md.getOwnProperty(key)
        break
      md = md.proto or @realm.mdproto(md.object)
    return prop

  has: (key, target = @object) ->
    md = this
    while md
      if md.hasOwnProperty(key)
        return true
      md = md.proto or @realm.mdproto(md.object)
    return false

  get: (key, target = @object) ->
    property = @searchProperty(key)
    if property instanceof AccessorPropertyMetadata
      return property.getter.call(target, key)
    if property instanceof DataPropertyMetadata
      return property.value
    return property

  set: (key, value, target = @object) ->
    property = @getOwnProperty(key)
    if property instanceof AccessorPropertyMetadata
      if property.setter
        property.setter.call(target, key, value)
        return true
      return false
    if property instanceof DataPropertyMetadata
      if property.writable
        property.value = value
        return true
      return false
    if property is undef and not @extensible
      return false
    @setOwnProperty(key, value)
    return true

  del: (key) ->
    if not @hasOwnProperty(key)
      return false
    property = @getOwnProperty(key)
    if property instanceof PropertyMetadata and not property.configurable
      return false
    @delOwnProperty(key)
    return true

  defineProperty: (key, property) ->
    if not @extensible
      return false
    @setOwnProperty(key, property)
    return true

  instanceOf: (klass) ->
    md = this
    while md != null
      if md.object == klass.prototype
        return true
      if not md.proto
        return md.object instanceof klass
      md = md.proto
    return false

  isEnumerable: (k) ->
    v = @properties[k] or @object[k]
    return not (v instanceof PropertyMetadata) or v.enumerable

  enumerateKeys: ->
    keys = []
    md = this
    while md
      keys = keys.concat(md.ownKeys())
      md = md.proto
    return new ArrayIterator(keys)


class CowObjectMetadata extends ObjectMetadata
  constructor: (object, realm) ->
    super(object, realm)
    @exclude = {}

  hasOwnProperty: (key) ->
    key of @properties or (key of @object and key not of @exclude)

  getOwnProperty: (key) ->
    if key of @properties
      return @properties[key]
    if key of @object and key not of @exclude
      return @object[key]
    return undef

  setOwnProperty: (key, value) ->
    if key of @exclude
      delete @exclude[key]
    if value != @properties[key]
      @properties[key] = value

  delOwnProperty: (key) ->
    if key of @properties
      delete @properties[key]
    @exclude[key] = null

  isEnumerable: (k) ->
    if k of @exclude
      return false
    return super(k)


# This ensures only explicitly specified builtin properties are leaked
# into the Realm
class RestrictedObjectMetadata extends CowObjectMetadata
  constructor: (object, realm) ->
    super(object, realm)
    @leak = {}

  hasOwnProperty: (key) ->
    key of @properties or
      (key of @leak and key of @object and key not of @exclude)

  getOwnProperty: (key) ->
    if key of @properties
      return @properties[key]
    if key of @leak and key of @object and key not of @exclude
      return @object[key]
    return undef


exports.ObjectMetadata = ObjectMetadata
exports.CowObjectMetadata = CowObjectMetadata
exports.RestrictedObjectMetadata = RestrictedObjectMetadata
exports.DataPropertyMetadata = DataPropertyMetadata
exports.AccessorPropertyMetadata = AccessorPropertyMetadata
