Vm = require '../src/vm'

tests =
  ## expressions
  # literals
  "({name: 'thiago', 'age': 28, 1: 2})": [{name: 'thiago', age: 28, 1: 2}]
  "[1, 2, [1, 2]]": [[1, 2, [1, 2]]]
  # unary
  '-{count: 2}.count': [-2]
  'x = 4; --x': [3, {x: 3}]
  'x = 4; ++x': [5, {x: 5}]
  'x = 4; x--': [4, {x: 3}]
  'x = 4; x++': [4, {x: 5}]
  'x = 5; -x': [-5, {x: 5}]
  'x = 5; +x': [5, {x: 5}]
  'x = 5; !x': [false, {x: 5}]
  'x = 5; ~x': [-6, {x: 5}]
  # binary
  '5 == 5': [true]
  '5 == "005"': [true]
  '5 == 4': [false]
  '5 == "004"': [false]
  '5 != 5': [false]
  '5 != "005"': [false]
  '5 != 4': [true]
  '5 === 5': [true]
  '5 === "005"': [false]
  '5 !== 5': [false]
  '5 !== "005"': [true]
  '5 !== 4': [true]
  'false || true': [true]
  'false || false': [false]
  'true && true': [true]
  'true && false': [false]
  '10 > 9': [true]
  '10 > 10': [false]
  '10 >= 10': [true]
  '10 < 9': [false]
  '10 < 10': [false]
  '10 <= 10': [true]
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
  # conditional expressions
  '3 ? 1 : 2': [1]
  'false ? 1 : 2': [2]
  # assignments
  "x = {count: 28};x.count = 29": [29, {x: {count: 29}}]
  "x = [1, 2, 3];x[2] = 5": [5, {x: [1, 2, 5]}]
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
  # destructuring assignments
  '[x, y] = [1, 2]': [[1, 2], {x: 1, y: 2}]
  '[,,y] = [1, 2, 3 ,4]': [[1, 2, 3, 4], {y: 3}]
  '({x: X, y: Y} = {x: 1, y: 2})': [{x: 1, y: 2}, {X: 1, Y: 2}]
  # control flow
  'i = 0; while(i++ < 10) { i++; }; i;': [11, {i: 11}]
  """
  i = 0;
  while (i < 1000) {
    j = 0;
    while (j < 100000) {
      j += 100;
      break;
    }
    i++;
  };
  i;
  """: [1000, {i: 1000, j: 100}]
  """
  i = 0; j = 0; k = 0;
  while (i < 1000) {
    while (j < 100000) {
      j += 100;
      while (true) {k+=2; break;}
      continue;
      i += 10000
    }
    i++;
  };
  i;
  """: [1000, {i: 1000, j: 100000, k: 2000}]
  """
  i = 0, j = 0
  do {
    j += 5
  } while (i++ < 10)
  i,j;
  """: [55, {i: 11, j: 55}]
  """
  obj = {length: 5};
  j = 0;
  for (i = 0, len = obj.length; i < len; i++) {
    j++;
  }
  i
  """: [5, {i: 5, j: 5, len: 5, obj: {length: 5}}]
  'for (var i = 0, len = 6; i < len; i+=10) { }; i': [10, {i: 10, len: 6}]
  '(function() { return 10; })()': [10]
  '(function() { var i = 4; return i * i; })()': [16]
  """
  i = 0;
  test();
  function test() { i = 10; }
  i
  """: [10, ((scope) ->
    expect(scope.i).to.eql(10)
    expect(scope.test.constructor.name).to.eql('Closure')
  )]
  """
  fn = function(a, b, c, d) {
    return a + b + c * d;
  }
  fn(4, 9, 10, 3);
  """: [43, (scope) -> expect(len(scope)).to.eql(1)]
  """
  fn = function(a, b=2, c=b*b, d=c) {
    return a + b + c + d;
  }
  fn(9);
  """: [19, (scope) -> expect(len(scope)).to.eql(1)]
  """
  fn = function(a, b=2, c=b*b, d=c, ...f) {
    return f;
  }
  fn(1, 2, 3, 4, 5, 6);
  """: [[5, 6], (scope) -> expect(len(scope)).to.eql(1)]

len = (obj) -> Object.keys(obj).length

describe 'vm eval', ->
  vm = null
  scope = null

  beforeEach ->
    vm = new Vm(256)
    scope = vm.global

  for k, v of tests
    do (k, v) ->
      fn = ->
        result = vm.eval(k, scope)
        expect(result).to.deep.eql expectedValue
        if typeof expectedScope == 'function'
          expectedScope(scope.keys)
        else if typeof expectedScope == 'object'
          expect(scope.keys).to.deep.eql expectedScope
        else
          expect(scope.keys).to.deep.eql {}
      test = "\"#{k}\""
      expectedValue = v[0]
      expectedScope = v[1]
      if 1 in [expectedScope, v[2]] then it.only(test, fn)
      else if 0 in [expectedScope, v[2]] then it.skip(test, fn)
      else it(test, fn)
