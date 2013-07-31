Vm = require '../src/vm'

tests =
  '2 + 2': 4
  '1023 - 5': 1018
  '70 * 7': 490
  '1000 / 10': 100

describe 'vm eval', ->
  vm = null

  beforeEach ->
    vm = new Vm()

  for k, v of tests
    do (k, v) ->
      it k, -> expect(vm.eval(k)).to.deep.eql v

