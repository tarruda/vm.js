{CowObjectMetadata} = require './metadata'


class RegExpProxy
  @__name__: 'RegExp'

  constructor: (@regexp, realm) ->
    @__md__ = new CowObjectMetadata(this, realm)
    @__md__.proto = RegExp.prototype

  exec: (str) -> @regexp.exec(str)

  test: (str) -> @regexp.test(str)


module.exports = RegExpProxy
