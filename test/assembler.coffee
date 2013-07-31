cat = require '../src/assembler'

describe 'test', ->
  it 'cat', ->
    expect(cat(1, 2)).to.eql '1|2'

