{CowObjectMetadata, DataPropertyMetadata} = require './metadata'


class RegExpProxy
  @__name__: 'RegExp'

  constructor: (@regexp, realm) ->
    @__md__ = new CowObjectMetadata(this, realm)
    @__md__.proto = realm.getNativeMetadata(RegExp.prototype)
    @__md__.defineProperty('global',
      new DataPropertyMetadata(regexp.global, false, true, false))
    @__md__.defineProperty('ignoreCase',
      new DataPropertyMetadata(regexp.ignoreCase, false, true, false))
    @__md__.defineProperty('multiline',
      new DataPropertyMetadata(regexp.multiline, false, true, false))
    @__md__.defineproperty('source',
      new DataPropertyMetadata(regexp.source, false, true, false))
    @lastIndex = 0

  exec: (str) ->
    @regexp.lastIndex = @lastIndex
    rv = @regexp.exec(str)
    @lastIndex = @regexp.lastIndex
    return rv

  test: (str) ->
    @regexp.lastIndex = @lastIndex
    rv = @regexp.test(str)
    @lastIndex = @regexp.lastIndex
    return rv

  toString: -> @regexp.toString()


module.exports = RegExpProxy
