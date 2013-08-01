Vm = require '../src/vm'

tests =
  '2 + 2': [4]
  '1023 - 5': [1018]
  '70 * 7': [490]
  '1000 / 10': [100]
  'x = 15': [15, {x: 15}]
  'x = 3;x += 8': [11, {x: 11}]

describe 'vm eval', ->
  vm = null
  scope = null

  beforeEach ->
    scope = {}
    vm = new Vm()

  for k, v of tests
    do (k, v) ->
      it k, ->
        expect(vm.eval(k, scope)).to.deep.eql v[0]
        if v[1]
          expect(v[1]).to.deep.eql scope

