Vm = require '../src/vm'
{Suite} = require 'benchmark'

suite = new Suite()
vm = new Vm()

loopVm = vm.compile(
  """
  function loop() {
    var i = 0;
    while (i < 1000000) {
      i++;
    }
  }
  loop();
  """
)

loopNative = ->
  i = 0
  while i < 1000000
    i++

suite
  .add 'native', ->
    loopNative()
  .add 'vm', ->
    vm.run(loopVm)
  .on 'complete', ->
    benchs = @filter('successful')
    console.log("Results:")
    for b in benchs
      console.log(b.name, "(#{b.count} times):", b.times, b.stats)
  .run(async: true)
