Vm = require '../src/vm'

tests =
  '2 + 2': [4]
  '1023 - 5': [1018]
  '70 * 7': [490]
  '1000 / 10': [100]
  'x = 15': [15, {x: 15}]
  'x = 3;x += 8': [11, {x: 11}]
  'x = 3;x -= 8': [-5, 0, {x: -5}]

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

