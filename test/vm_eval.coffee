Vm = require '../src/vm'

tests =
  '2 + 2': [4]
  '1023 - 5': [1018]
  '70 * 7': [490]
  '1000 / 10': [100]
  '27 % 10': [7]
  '2 << 1': [4]
  '0xffffffff >> 1': [-1]
  '0x0fffffff >> 1': [0x7ffffff]
  '0xffffffff >>> 1': [0x7fffffff]
  '0xf | 0xf0': [0xff]
  '0xf & 0xf8': [8]
  '0xf0 ^ 8': [0xf8]
  'x = 15': [15, {x: 15}]
  'x = 3;x += 8': [11, {x: 11}]
  'x = 3;x -= 8': [-5, {x: -5}]
  'x = 50;x *= 5': [250, {x: 250}]
  'x = 300;x /= 5': [60, {x: 60}]
  'x = 1000;x %= 35': [20, {x: 20}]
  'x = 5;x <<= 3': [40, {x: 40}]
  'x = 0xffffffff;x >>= 1': [-1, {x: -1}]
  'x = 0x0fffffff;x >>= 1': [0x7ffffff, {x: 0x7ffffff}]
  'x = 0xffffffff;x >>>= 1': [0x7fffffff, {x: 0x7fffffff}]
  'x = 0xf;x |= 0xf0': [0xff, {x: 0xff}]
  'x = 0xf;x &= 0xf8': [8, {x: 8}]
  'x = 0xf0;x ^= 8': [0xf8, {x: 0xf8}]

describe 'vm eval', ->
  vm = null
  scope = null

  beforeEach ->
    scope = {}
    vm = new Vm()

  for k, v of tests
    do (k, v) ->
      fn = ->
        expect(vm.eval(k, scope)).to.deep.eql expectedValue
        if v[1] then expect(scope).to.deep.eql expectedScope
        else expect(scope).to.deep.eql {}
      expectedValue = v[0]
      expectedScope = v[1]
      if typeof expectedScope == 'number'
        if expectedScope == 1 then it.only(k, fn)
        else if expectedScope == 0 then it.skip(k, fn)
        expectedScope = v[2]
      else
        it(k, fn)

