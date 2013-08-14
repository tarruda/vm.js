Vm = require '../src/vm'

tests =
  ## expressions
  # literals
  "({name: 'thiago', 'age': 28, 1: 2})": [{name: 'thiago', age: 28, 1: 2}]
  "[1, 2, [1, 2]]": [[1, 2, [1, 2]]]
  # unary
  '-{count: 2}.count': [-2]
  "x = {count: 28};x.count++": [28, {x: {count: 29}}]
  "x = {count: 30};--x.count": [29, {x: {count: 29}}]
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
  "x = {count: 28};x.count += 10": [38, {x: {count: 38}}]
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
  'var [x, y] = [1, 2]': [[1, 2], {x: 1, y: 2}]
  '[,,y] = [1, 2, 3 ,4]': [[1, 2, 3, 4], {y: 3}]
  '({x: X, y: Y} = {x: 1, y: 2})': [{x: 1, y: 2}, {X: 1, Y: 2}]
  '({x, y} = {x: 1, y: 2})': [{x: 1, y: 2}, {x: 1, y: 2}]
  'var {x, y} = {x: 1, y: 2}': [{x: 1, y: 2}, {x: 1, y: 2}]
  # nested destructuring
  'var [a,,[b,,[c]]] = [1,0,[2,0,[3]]];': [[1,0,[2,0,[3]]], {a:1,b:2,c:3}]
  'var {op: a, lhs: {op: b}, rhs: c} = {op: 1, lhs: {op: 2}, rhs: 3};':
    [{op: 1, lhs: {op: 2}, rhs: 3}, {a:1,b:2,c:3}]
  # control flow
  "if (5 > 4) i = 1; else i = 2": [1, {i: 1}]
  "if (4 > 5) i = 1; else i = 4": [4, {i: 4}]
  'i = 0; while(i++ < 10) i++; i;': [11, {i: 11}]

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

  """
  obj = {name: '1', address: 2, email: 3};
  l = []
  for (var k in obj) l.push(k)
  l.sort()
  null
  """: [null, ((global) ->
    expect(global.l).to.deep.eql(['address', 'email', 'name'])
  )]

  """
  l = [];
  fruits = ['orange', 'apple', 'lemon'];
  for (var k of fruits) l.push(k)
  null
  """: [null, ((global) ->
    expect(global.l).to.deep.eql(['orange', 'apple', 'lemon'])
    expect('k' of global).to.be.true
  )]

  """
  l = [];
  fruits = ['orange', 'apple', 'lemon'];
  for (let k of fruits) l.push(k)
  null
  """: [null, ((global) ->
    expect(global.l).to.deep.eql(['orange', 'apple', 'lemon'])
    expect('k' of global).to.be.false
  )]

  """
  obj = [[1, 2], [3, 4], [5, 6]];
  l = []
  for (var [x,y] = obj[0], i = 1; i < obj.length; [x,y] = obj[i++]) {
    l.push(x); l.push(y);
  }
  l
  """: [[1, 2, 3, 4], ((global) ->)]

  """
  var i, j;
  var l = [];
  loop1:
  for (i = 0; i < 3; i++) {
     loop2:
     for (j = 0; j < 3; j++)
        if (i == 1 && j == 1) continue loop1;
        else l.push(i), l.push(j);
  }
  i
  """: [3, {i: 3, j: 3, l: [0, 0, 0, 1, 0, 2, 1, 0, 2, 0, 2, 1, 2, 2]}]

  """
  var i, j;
  var l = [];
  loop1:
  for (i = 0; i < 3; i++) {
     loop2:
     for (j = 0; j < 3; j++)
        if (i == 1 && j == 1) break loop1;
        else l.push(i), l.push(j);
  }
  j
  """: [1, {i: 1, j: 1, l: [0, 0, 0, 1, 0, 2, 1, 0]}]

  'for (var i = 0, len = 6; i < len; i+=10) {}; i': [10, {i: 10, len: 6}]
  '(function() { return 10; })()': [10]
  '(function() { var i = 4; return i * i; })()': [16]
  '(function named() { var i = 4; return i * i; })()': [16]

  """
  i = 0;
  test();
  function test() { i = 10; }
  i
  """: [10, ((global) ->
    expect(global.i).to.eql(10)
    expect(global.test.constructor.name).to.eql('Closure')
  )]

  """
  fn = function(a, b, c, d) {
    return a + b + c * d;
  }
  fn(4, 9, 10, 3);
  """: [43, ((global) ->)]

  """
  fn = function(a, b=2, c=b*b, d=c) {
    return a + b + c + d;
  }
  fn(9);
  """: [19, ((global) ->)]

  """
  fn = function(a, b=2, c=b*b, d=c, ...f) {
    return f;
  }
  fn(1, 2, 3, 4, 5, 6);
  """: [[5, 6], ((global) ->)]

  """
  fn = function([n1, n2], {key, value}) {
    return [n1 + n2, key, value];
  }
  fn([5, 4], {key: 'k', value: 'v'});
  """: [[9, 'k', 'v'], ((global) ->)]

  """
  function fn1() {
    try {
      fn2();
      return 3;
    } catch (e) {
      a = e
      return 5;
    }
  }
  function fn2() {
    throw 'error'
  }
  fn1();
  """: [5, ((global) ->
    expect(global.e).to.not.exist # 'e' should be local to the catch block
    expect(global.a).to.eql('error'))]
    # ((global) -> expect(global.a).to.eql('error')), 1]

  """
  function fn1() {
    try {
      fn2();
    } catch ([a,,[b,,[c]]]) {
      ex = [a, b, c];
      i = 10; return 1;
    } finally { return 5; i = 2}
  }
  function fn2() {
    throw [1,0,[2,0,[3]]];
  }
  fn1()
  """: [5, ((global) ->
    expect(global.i).to.eql(10)
    expect(global.a).to.not.exist
    expect(global.b).to.not.exist
    expect(global.c).to.not.exist
    expect(global.ex).to.eql([1, 2, 3])
  )]

  """
  function fn1() {
    try {
      fn2();
      return 3;
    } catch ({op: a, lhs: {op: b}, rhs: c}) {
      ex = [a, b, c];
      return i + 1;
    } finally {
      j = 10;
    }
  }
  function fn2() {
    try {
      fn3();
    } finally {
      i = 11;
    }
  }
  function fn3() {
    try {
      throw 'error'
    } catch (e) {
      throw {op: 1, lhs: {op: 2}, rhs: 3};
    }
  }
  fn1();
  """: [12, ((global) ->
    expect(global.i).to.eql(11)
    expect(global.j).to.eql(10)
    expect(global.a).to.not.exist
    expect(global.b).to.not.exist
    expect(global.c).to.not.exist
    expect(global.ex).to.eql([1, 2, 3])
  )]

  """
  try {
    throw 'err'
  } catch (e) {
    ex = e;
  }
  """: ['err', ((global) ->
    expect(global.e).to.not.exist
    expect(global.ex).to.eql('err')
  )]
len = (obj) -> Object.keys(obj).length

describe 'vm eval', ->
  vm = null

  beforeEach ->
    vm = new Vm(256)

  for k, v of tests
    do (k, v) ->
      fn = ->
        result = vm.eval(k)
        expect(result).to.deep.eql expectedValue
        if typeof expectedGlobal is 'function'
          expectedGlobal(vm.context.global)
        else if typeof expectedGlobal is 'object'
          expect(strip(vm.context.global)).to.deep.eql expectedGlobal
        else
          expect(strip(vm.context.global)).to.deep.eql {}
      test = "\"#{k}\""
      expectedValue = v[0]
      expectedGlobal = v[1]
      if 1 in [expectedGlobal, v[2]] then it.only(test, fn)
      else if 0 in [expectedGlobal, v[2]] then it.skip(test, fn)
      else it(test, fn)


  strip = (global) ->
    # strip builtins for easy assertion of global object state
    delete global.Object
    delete global.Number
    delete global.Boolean
    delete global.String
    delete global.Array
    delete global.Date
    delete global.RegExp
    delete global.Error
    delete global.EvalError
    delete global.RangeError
    delete global.ReferenceError
    delete global.SyntaxError
    delete global.TypeError
    delete global.URIError
    delete global.Math
    delete global.JSON
    delete global.StopIteration

    return global
