{CowObjectMetadata} = require './metadata'
{defProp} = require './util'


class RegExpProxy
  @__name__: 'RegExp'

  constructor: (@regexp, realm) ->
    @lastIndex = 0
    md = new CowObjectMetadata(this, realm)
    md.proto = realm.getNativeMetadata(RegExp.prototype)
    md.defineProperty('global', {value: regexp.global})
    md.defineProperty('ignoreCase', {value: regexp.ignoreCase})
    md.defineProperty('multiline', {value: regexp.multiline})
    md.defineProperty('source', {value: regexp.source})
    defProp(this, '__md__', {
      value: md
      writable: true
    })


module.exports = RegExpProxy
