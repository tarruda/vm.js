Vm = require '../src/vm'

# flag to enable/disable running the tests from a self-hosted vm
selftest = 1
# flag to enable/disable running the tests from a native vm
nativetest = 1

# what follows is a bunch of test cases to be run in a Vm instance.
# the key is the string to be eval'ed and the value is an array where:
# - the first item is the result of the expression that was evaluated last
# - if the second item is an object, it is treated as an expectation for the
#   global object
# - if its a function its called with the vm global object as argument
# - if the last argument is 1, then only that test is ran. if its 0 that test
#   is skipped

tests = {
  ## expressions
  # literals
  "({name: 'thiago', 'age': 28, 1: 2})": [{name: 'thiago', age: 28, 1: 2}]
  "'abc'": ['abc']
  "[1, 2, [1, 2]]": [[1, 2, [1, 2]]]
  "'abc'[1]": ['b']
  "'abc'.length": [3]
  "/abc/gi === /abc/gi": [false]
  # unary
  'void(0)': [undefined]
  'void(x=1)': [undefined, {x: 1}]
  'typeof 5': ['number']
  'typeof undef': ['undefined']
  'n=5; typeof n': ['number', {n: 5}]
  'typeof true': ['boolean']
  'b=true; typeof b': ['boolean', {b: true}]
  'o={prop1: 1, prop2: 2}; delete o.prop1': [true, {o:{prop2:2}}]
  'o={prop1: 1, prop2: 2}; delete o["prop2"]': [true, {o:{prop1:1}}]
  'delete Array': [true, ((global) ->
    expect('Object' of global).to.eql(true)
    expect('Array' of global).to.eql(false)
  )]
  # deleting local variables is a no-op and returns false(according to v8)
  '(function(){var x = 1; return delete x;})()': [false]
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
  "if (5 > 4) i = 1;": [1, {i: 1}]
  "if (5 > 4) i = 1; else i = 2": [1, {i: 1}]
  "if (4 > 5) i = 1;": [null]
  "if (4 > 5) i = 1; else i = 4": [4, {i: 4}]
  'i = 0; while(i++ < 10) i++; i;': [11, {i: 11}]
  # other acceptance tests
  """
  l = ['1', 2, 'age', 28, 'name', 'thiago'];
  obj = {}
  while (l.length) obj[l.pop()] = l.pop();
  obj;
  """: [{name: 'thiago', 'age': 28, 1: 2}, ((global) -> )]

  """
  (function() {})()
  """: [undefined]

  """
  x = 5;
  this[++x] = 10;
  """: [10, ((global) ->
    expect(global[6]).to.eql(10)
  )]

  """
  obj = {
    isTrue: function(obj) { return 'isTrue' in obj }
  }
  l = [];

  (function() {
    for (var k in obj) {
      if (obj.isTrue.call(obj, obj)) l.push('isTrue');
    }
    function test() { }
  })();
  l
  """: [['isTrue'], ((global) -> )]

  """
  obj = {
    isTrue: function(obj) { return 'isTrue' in obj }
  }
  l = [];

  (function() {
    for (var k in obj) {
      if (obj.isTrue.call(obj, obj)) l.push('isTrue');
      function test() { }
    }
  })();
  l
  """: [['isTrue'], ((global) -> )]

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
    expect(global.l).to.eql(['address', 'email', 'name'])
  )]

  # the below fails because its parsed as l(function...)
  """
  obj = {name: '1', address: 2, email: 3};
  l = []
  (function() {
    for (k in obj) l.push(k)
  })();
  """: [undefined, ((global) ->
    expect(global.errorThrown.stack).to.be(
      """
      TypeError: object is not a function
          at <script>:2:37
      """
    )
  )]


  """
  obj = {name: '1', address: 2, email: 3};
  l = [];
  (function() {
    for (k in obj) l.push(k)
  })();
  l.sort()
  null
  """: [null, ((global) ->
    expect(global.l).to.eql(['address', 'email', 'name'])
    expect('k' not of global).to.be(false)
  )]

  """
  obj = {name: '1', address: 2, email: 3};
  l = [];
  (function() {
    var k;
    for (k in obj) l.push(k)
  })();
  l.sort()
  null
  """: [null, ((global) ->
    expect(global.l).to.eql(['address', 'email', 'name'])
    expect('k' not of global).to.be(true)
  )]

  """
  l = [];
  fruits = ['orange', 'apple', 'lemon'];
  for (var k of fruits) l.push(k)
  null
  """: [null, ((global) ->
    expect(global.l).to.eql(['orange', 'apple', 'lemon'])
    expect('k' of global).to.eql(true)
  )]

  """
  l1 = [1, 2]
  l2 = [3, 4]
  l3 = [5, 6]
  l = [];
  for (let i = 0; i < l1.length;i++) {
    for (let j = 0; j < l2.length;j++) {
      for (let k = 0; k < l3.length;k++) {
        l.push([l1[i], l2[j], l3[k]]);
      }
    }
  }
  null
  """: [null, ((global) ->
    expect(global.l).to.eql([[1, 3, 5], [1, 3, 6], [1, 4, 5], [1, 4, 6],
      [2, 3, 5], [2, 3, 6], [2, 4, 5], [2, 4, 6]])
  )]

  """
  l = [];
  for (var i of [1, 2]) {
    for (var j of [3, 4]) {
      for (var k of [5, 6]) {
        l.push([i, j, k]);
      }
    }
  }
  null
  """: [null, ((global) ->
    expect(global.l).to.eql([[1, 3, 5], [1, 3, 6], [1, 4, 5], [1, 4, 6],
      [2, 3, 5], [2, 3, 6], [2, 4, 5], [2, 4, 6]])
  )]

  """
  for (let i of [1, 2]) {
    for (var j of [3, 4]) {
      for (let k of [5, 6]) {
      }
    }
  }
  null
  """: [null, ((global) ->
    expect(global.j).to.eql(4)
    expect('i' of global).to.eql(false)
    expect('k' of global).to.eql(false)
  )]

  """
  l = [];
  outer:
  for (var i of [1, 2]) {
    for (var j of [3, 4]) {
      for (var k of [5, 6]) {
        l.push([i, j, k]);
        break outer;
      }
    }
  }
  null
  """: [null, ((global) ->
    expect(global.l).to.eql([[1, 3, 5]])
  )]

  """
  l = [];
  outer:
  for (var i of [1, 2]) {
    for (let j of [3, 4]) {
      for (var k of [5, 6]) {
        l.push([i, j, k]);
        continue outer;
      }
    }
  }
  null
  """: [null, ((global) ->
    expect(global.l).to.eql([[1, 3, 5], [2, 3, 5]])
  )]

  """
  l = [];
  for (let i of [1, 2]) {
    outer:
    for (var j of [3, 4]) {
      for (let k of [5, 6]) {
        l.push([i, j, k]);
        break outer;
      }
    }
  }
  null
  """: [null, ((global) ->
    expect(global.l).to.eql([[1, 3, 5], [2, 3, 5]])
  )]

  """
  l = [];
  for (let i of [1, 2]) {
    outer:
    for (let j of [3, 4]) {
      for (let k of [5, 6]) {
        l.push([i, j, k]);
        continue outer;
      }
    }
  }
  null
  """: [null, ((global) ->
    expect(global.l).to.eql([[1, 3, 5], [1, 4, 5], [2, 3, 5], [2, 4, 5]])
  )]

  """
  l = [];
  fruits = ['orange', 'apple', 'lemon'];
  for (let k of fruits) l.push(k)
  null
  """: [null, ((global) ->
    expect(global.l).to.eql(['orange', 'apple', 'lemon'])
    expect('k' of global).to.eql(false)
  )]

  """
  obj = [[1, 2], [3, 4], [5, 6]];
  l = []
  for (var [x,y] = obj[0], i = 1; i < obj.length; [x,y] = obj[i++]) {
    l.push(x); l.push(y);
  }
  l
  """: [[1, 2, 3, 4], ((global) -> )]

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
  )]

  """
  (function() {
    return a();
    function b() {
      return 5;
    }
    function a() {
      return b();
      function b() {
        return 6;
      }
    }
  })();
  """: [6]

  """
  fn = function(a, b, c, d) {
    return a + b + c * d;
  }
  fn(4, 9, 10, 3);
  """: [43, ((global) -> )]

  """
  fn = function(a, b=2, c=b*b, d=c) {
    return a + b + c + d;
  }
  fn(9);
  """: [19, ((global) -> )]

  """
  fn = function(a, b=2, c=b*b, d=c, ...f) {
    return f;
  }
  fn(1, 2, 3, 4, 5, 6);
  """: [[5, 6], ((global) -> )]

  """
  fn = function([n1, n2], {key, value}) {
    return [n1 + n2, key, value];
  }
  fn([5, 4], {key: 'k', value: 'v'});
  """: [[9, 'k', 'v'], ((global) -> )]

  """
  function switchCleanup(x) {
    switch (x) {
      case 9:
        return 4;
        break
      case '10':
        return 5
        break;
      default:
        return 6;
        break
    }
  }
  switchCleanup('10')
  """: [5, ((global) -> )]

  """
  x = '10'
  switch (x) {
    case 9:
      z = 4;
      break
    case '10':
      z = 5;
      break;
    default:
      z = 6;
      break
  }
  z
  """: [5, ((global) -> )]

  """
  x = 10
  z = 0
  switch (x) {
    case 10:
    case 9:
    case 8:
      z = 2;
      break
    default:
      z = 3;
  }
  z
  """: [2, ((global) -> )]

  """
  x = 9
  z = 0
  switch (x) {
    case 10:
    case 9:
      z = 2;
    case 8:
      break
    default:
      z = 10;
  }
  z
  """: [2, ((global) -> )]

  """
  x = 8
  z = 0
  switch (x) {
    case 10:
    case 9:
      z = 2;
    case 8:
      break
    default:
      z = 10;
  }
  z
  """: [0, ((global) -> )]

  """
  z = 0
  grandparent:
  switch (10) {
    case 9:
    case 10:
      parent:
      switch (3 + 3) {
        case 7:
          z += 1
          break;
        case 6:
          child:
          switch (4+1) {
            case 5:
              z += 50
              break grandparent;
            case 10:
              z += 100;
          }
          z += 10;
      }
      z += 2;
  }
  z
  """: [50, ((global) -> )]

  """
  z = 0
  grandparent:
  switch (10) {
    case 9:
    case 10:
      parent:
      switch (3 + 3) {
        case 7:
          z += 1
          break;
        case 6:
          child:
          switch (4+1) {
            case 5:
              z += 50
              break parent;
            case 10:
              z += 100;
          }
          z += 10;
      }
      z += 2;
  }
  z
  """: [52, ((global) -> )]

  """
  z = 0
  grandparent:
  switch (10) {
    case 9:
    case 10:
      parent:
      switch (3 + 3) {
        case 7:
          z += 1
          break;
        case 6:
          child:
          switch (4+1) {
            case 5:
              z += 50
              break;
            case 10:
              z += 100;
          }
          z += 10;
      }
      z += 2;
  }
  z
  """: [62, ((global) -> )]

  """
  z = 0
  grandparent:
  switch (10) {
    case 9:
    case 10:
      parent:
      switch (3 + 3) {
        case 7:
          z += 1
          break;
        case 6:
          child:
          switch (4+1) {
            case 5:
              z += 50
            case 10:
              z += 100;
          }
          z += 10;
      }
      z += 2;
  }
  z
  """: [162, ((global) -> )]

  """
  x = 10
  z = 0
  switch (x) {
    case 10:
      let y = 10
    case 9:
      y += 10
    case 8:
      y += 10
      z = y
      break
    default:
      z = 10;
  }
  z
  """: [30, ((global) ->
    expect(global.z).to.eql(30)
    expect('y' of global).to.eql(false))]

  """
  x = 10
  z = 0
  switch (x) {
    case 10:
      z += 2
    case 9:
      z += 2
      break;
    case 8:
      z += 2
      break
    default:
      z = 10;
  }
  z
  """: [4, ((global) -> )]

  """
  throw new EvalError('err')
  """: [undef, ((global) ->
    expect(global.errorThrown.stack).to.eql(
      """
      EvalError: err
          at <script>:1:10
      """
    )
  )]

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

  """
  try {
    throw 'err'
  } catch (e) {
    throw e;
  } finally {
    (function() { obj = [1, 2] })();
  }
  """: [undefined, ((global) ->
    expect(global.errorThrown).to.eql('err')
    expect(global.obj).to.eql([1, 2])
  )]

  """
  errors = []
  for (let i of [1, 2]) {
    for (var j of [3, 4]) {
      for (let k of [5, 6]) {
        try {
          throw i
        } catch (e) {
          errors.push(e);
        }
      }
    }
  }
  errors
  """: [[1, 1, 1, 1, 2, 2, 2, 2], ((global) -> )]

  """
  errors = []
  for (let i of [1, 2]) {
    for (var j of [3, 4]) {
      try {
        for (let k of [5, 6]) {
          throw j
        }
      } catch (e) {
        errors.push(e);
      }
    }
  }
  errors
  """: [[3, 4, 3, 4], ((global) -> )]

  """
  errors = []
  for (let i of [1, 2]) {
    try {
      for (var j of [3, 4]) {
        for (let k of [5, 6]) {
          throw k
        }
      }
    } catch (e) {
      errors.push(e);
    }
  }
  errors
  """: [[5, 5], ((global) -> )]

  """
  errors = []
  try {
    for (let i of [1, 2]) {
      for (var j of [3, 4]) {
        for (let k of [5, 6]) {
          try {
            throw [k, j, i]
          } finally {
          }
        }
      }
    }
  } catch (e) {
    errors.push(e)
  }
  errors
  """: [[[5, 3, 1]], ((global) -> )]

  """
  errors = []
  for (let i of [1, 2]) {
    try {
      for (var j of [3, 4]) {
        for (let k of [5, 6]) {
          try {
            throw [k, j, i]
          } finally { }
        }
      }
    } catch (e) {
      errors.push(e)
    }
  }
  errors
  """: [[[5, 3, 1], [5, 3, 2]], ((global) -> )]

  """
  errors = []
  for (let i of [1, 2]) {
    for (var j of [3, 4]) {
      try {
        for (let k of [5, 6]) {
          try {
            throw [k, j, i]
          } finally { }
        }
      } catch (e) {
        errors.push(e)
      }
    }
  }
  errors
  """: [[[5, 3, 1], [5, 4, 1], [5, 3, 2], [5, 4, 2]], ((global) -> )]

  # errors/stacktrace
  """
  s = null
  s.name = 1
  """: [undef, ((global) ->
    errString = global.errorThrown.toString()
    expect(errString).to.eql(
      """
      TypeError: Cannot set property 'name' of null
          at <script>:2:0
      """
    )
  )]

  """
  function abc() {
    x = 5
    def();
    y = 1
  }

  function def() {
    y()
  }

  y = function() {
    var x = function ghi() {
      s = undefined
      s.name = 1
    }
    x()
  }

  abc()
  """: [undef, ((global) ->
    errString = global.errorThrown.toString()
    expect(errString).to.eql(
      """
      TypeError: Cannot set property 'name' of undefined
          at ghi (<script>:14:4)
          at y (<script>:16:2)
          at def (<script>:8:2)
          at abc (<script>:3:2)
          at <script>:19:0
      """
    )
  )]

  """
  obj = {
    getName: function() {
      return n;
    }
  }

  function name() {
    obj.getName()
  }

  (function() {
    name()
  })()
  """: [undef, ((global) ->
    errString = global.errorThrown.toString()
    expect(errString).to.eql(
      """
      ReferenceError: n is not defined
          at Object.getName (<script>:3:11)
          at name (<script>:8:2)
          at <anonymous> (<script>:12:2)
          at <script>:11:1
      """
    )
  )]

  """
  function withScope() {
    let k = 3
    let obj = {i: 1, j: 2}

    with (obj) {
      i = 10;
      j = i * 2;
      k = j * 3;
      l = k * 4;
    }

    return [obj, k];
  }

  withScope()
  """: [[{j: 20, i: 10}, 60], ((global) ->
    expect(global.l).to.eql(240)
    expect('k' of global).to.eql(false)
    expect('i' of global).to.eql(false)
    expect('j' of global).to.eql(false)
  )]

  """
  function fn() {
    return this._id++;
  }

  _id = 10;

  idGen = {
    _id: 1,
    id: fn
  };

  fn(); fn(); fn();

  l = [idGen.id(), idGen.id(), idGen.id()]
  _id++
  ++this._id
  """: [15, ((global) ->
    expect(global._id).to.eql(15)
    expect(global.l).to.eql([1, 2, 3])
  )]

  # construct native classes instances
  """
  new Date(2013, 7, 17)
  """: [new Date(2013, 7, 17)]

  """
  new Array(3, 2, 1)
  """: [[3, 2, 1]]

  """
  new Array(3)
  """: [new Array(3)]

  """
  new RegExp('abc', 'gi')
  """: [/abc/gi]

  """
  [new Number(1), new Number(null), new Number(undefined)]
  """: [[new Number(1), new Number(null), new Number(undef)]]

  """
  [new Boolean(1), new Boolean(null), new Boolean(undefined)]
  """: [[new Boolean(1), new Boolean(null), new Boolean(undef)]]

  """
  dog = new Dog()
  dog.bark()
  """: [true, ((global) ->
    expect(global.dog).to.be.a(merge.Dog)
    expect(global.dog.barked).to.eql(true)
  )]

  # native methods
  """
  (5.5).toExponential().split('.')
  """: [['5', '5e+0']]

  """
  [1, 2].concat([3, 4], [5, 6])
  """: [[1, 2, 3, 4, 5, 6]]

  """
  /(a)(b)(c)/.exec('abc').slice()
  """: [['abc', 'a', 'b', 'c']]

  """
  /a/ instanceof RegExp
  """: [true]

  """
  new RegExp('abc').constructor
  """: [RegExp]

  """
  /abc/.constructor
  """: [RegExp]

  """
  null instanceof Object
  """: [false]

  """
  r = /a/gi;
  r.global = false;
  r.ignoreCase = false;
  r.multiline = true;
  [r.global, r.ignoreCase, r.multiline, r.source]
  """: [[true, true, false, 'a'], ((global) -> )]

  """
  r = /\\d+/g
  l = []
  while (match = r.exec('1/13/123')) l.push(match[0])
  l
  """: [['1', '13', '123'], ((global) -> )]

  # each instance has its own 'lastIndex' copy which is used when matching
  """
  r1 = /\\d+/g
  r2 = /\\d+/g
  l = []
  l.push(r1.exec('1/13/123')[0])
  l.push(r1.exec('1/13/123')[0])
  l.push(r2.exec('1/13/123')[0])
  l.push(r1.exec('1/13/123')[0])
  l
  """: [['1', '13', '1', '123'], ((global) ->
    expect(global.r1.lastIndex).to.eql(8)
    expect(global.r2.lastIndex).to.eql(1)
    # while each literal maintain its own state, they both share
    # the same compiled regexp
    expect(global.r1.regexp).to.eql(global.r2.regexp)
  )]

  # String.prototype.match considers RegExpProxy instances
  """
  '1/13/123'.match(/\\d+/g)
  """: [['1', '13', '123'], ((global) -> )]

  # builtin sandboxing
  """
  Object.prototype.custom = 123
  x = Object.prototype.custom
  x
  """: [123, ((global) ->
    expect('custom' of Object.prototype).to.eql(false)
  )]

  """
  x = Math.abs(-5);
  delete Math.abs;
  try {
    y = Math.abs(-5);
  } catch (e) {
    err = e;
  }
  'abs' in Math
  """: [false, ((global) ->
    expect(global.x).to.be(5)
    expect('y' of global).to.be(false)
    expect(global.err.stack).to.be(
      """
      TypeError: Object #<Object> has no method 'abs'
          at <script>:4:6
      """
    )
    expect('abs' of global.Math).to.be(true)
  )]

  """
  x = JSON.stringify(-5);
  JSON.stringify = 5;
  try {
    y = JSON.stringify(-5);
  } catch (e) {
    err = e;
  }
  'stringify' in JSON
  """: [true, ((global) ->
    expect(global.x).to.be('-5')
    expect('y' of global).to.be(false)
    expect(global.err.stack).to.be(
      """
      TypeError: Property 'stringify' of object #<Object> is not a function
          at <script>:4:6
      """
    )
    expect(global.JSON.stringify).to.be.a(Function)
  )]

  # special runtime properties are handled specially
  """
  f = function(){};
  o = {'__md__': 'd'};
  assertions1 = [
    '__mdid__' in Object,
    '__mdid__' in Object.prototype,
    '__vmfunction__' in f,
    '__md__' in o
  ]
  Object.__mdid__ = 'a';
  Object.prototype.__mdid__ = 'b';
  f.__vmfunction__ = 'c';
  delete o.__md__;
  assertions2 = [
    '__mdid__' in Object,
    '__mdid__' in Object.prototype,
    '__vmfunction__' in f,
    '__md__' in o
  ];
  [
    Object.__mdid__,
    Object.prototype.__mdid__,
    f.__vmfunction__,
    o.__md__
  ]
  """:[['a', 'b', 'c', undefined], ((global) ->
    expect(global.o).to.have.property('__md__')
    expect(Object.__mdid__).to.be(1)
    expect(Object.prototype.__mdid__).to.be(2)
    expect(global.f.__vmfunction__).to.be(true)
    expect(global.assertions1).to.eql([
      false
      false
      false
      true
    ])
    expect(global.assertions2).to.eql([
      true
      true
      true
      false
    ])
  )]

  """
  currentId = 5;
  Object.__mdid__ = currentId + 1;
  currentId = Object.__mdid__;
  Object.prototype.__mdid__ = currentId + 1;
  currentId = Object.prototype.__mdid__;
  Function.__mdid__ = currentId + 1;
  currentId = Function.__mdid__;
  Function.prototype.__mdid__ = currentId + 1;
  currentId = Function.prototype.__mdid__;
  [
    currentId,
    Function.prototype.__mdid__,
    Function.__mdid__,
    Object.prototype.__mdid__,
    Object.__mdid__
  ];
  """: [[9, 9, 8, 7, 6], ((global) ->
    expect(Object.__mdid__).to.be(1)
    expect(Object.prototype.__mdid__).to.be(2)
    expect(Object.prototype.toString.__mdid__).to.be(3)
    expect(Function.__mdid__).to.be(4)
    expect(Function.prototype.__mdid__).to.be(5)
  )]

  """
  delete Object.prototype
  delete Number.prototype
  delete Boolean.prototype
  delete String.prototype
  delete Date.prototype
  delete RegExp.prototype
  """: [false, ((global) ->
    expect(global.Object.prototype).to.be(Object.prototype)
    expect(global.Number.prototype).to.be(Number.prototype)
    expect(global.Boolean.prototype).to.be(Boolean.prototype)
    expect(global.String.prototype).to.be(String.prototype)
    expect(global.Date.prototype).to.be(Date.prototype)
    expect(global.RegExp.prototype).to.be(RegExp.prototype)
  )]

  """
  (Object.prototype = Number.prototype = Boolean.prototype =
    String.prototype = Date.prototype = RegExp.prototype =
      {name: 'replacement'});
  """: [{name: 'replacement'}, ((global) ->
    expect(global.Object.prototype).to.be(Object.prototype)
    expect(global.Number.prototype).to.be(Number.prototype)
    expect(global.Boolean.prototype).to.be(Boolean.prototype)
    expect(global.String.prototype).to.be(String.prototype)
    expect(global.Date.prototype).to.be(Date.prototype)
    expect(global.RegExp.prototype).to.be(RegExp.prototype)
  )]

  """
  i = 1
  Object.prototype.bark = function() { return 'bark' + i++ };
  [({}).bark(), [].bark(), new Date().bark()]
  """: [['bark1', 'bark2', 'bark3'], ((global) ->
    expect('bark' of Object.prototype).to.eql(false)
  )]

  # prototype chains
  """
  function Person(firstname, lastname) {
    this.firstname = firstname;
    this.lastname = lastname;
  }
  Person.prototype.fullname = function() {
    return this.firstname + ' ' + this.lastname;
  };

  function Employee(firstname, lastname) {
    Person.call(this, firstname, lastname)
  }
  Employee.prototype = Object.create(Person.prototype)
  Employee.prototype.toString = function() {
    return 'employee: ' + this.fullname()
  };

  function Programmer() {
    Employee.apply(this, arguments)
  }
  Programmer.prototype = new Employee()
  Programmer.prototype.fullname = function() {
    return 'programmer: ' + Employee.prototype.fullname.call(this);
  };

  hasOwn = [
    Person.prototype.hasOwnProperty('fullname'),
    Employee.prototype.hasOwnProperty('fullname'),
    Programmer.prototype.hasOwnProperty('fullname')
  ]

  p1 = new Person('john', 'doe');
  p2 = new Employee('thiago', 'arruda');
  p3 = new Programmer('linus', 'torvalds');
  p1str = p1.toString()
  p1name = p1.fullname()
  p2name = p2.toString()
  p3name = p3.toString();
  (
    p1 instanceof Person &&
    !(p1 instanceof Employee) &&
    !(p1 instanceof Programmer) &&
    p2 instanceof Person &&
    p2 instanceof Employee &&
    !(p2 instanceof Programmer) &&
    p3 instanceof Person &&
    p3 instanceof Employee &&
    p3 instanceof Programmer
  )
  """: [true, ((global) ->
    expect(global.p1).to.be.a(global.Person)
    expect(global.p1str).to.eql('[object Object]')
    expect(global.p1name).to.eql('john doe')
    expect(global.p2name).to.eql('employee: thiago arruda')
    expect(global.p3name).to.eql('employee: programmer: linus torvalds')
    expect(global.hasOwn).to.eql([true, false, true])
  )]

  """
  z = 0;
  x=1; function hello(name) {
    if (name)
      return 'hello' + name;
    return 'hello world';
   } y = 2;
  hello.toString()
  """: [
    """
    function hello(name) {
      if (name)
        return 'hello' + name;
      return 'hello world';
     }
    """
    ((global) -> )
  ]

  """
  x = 1
  eval('x+2');
  """: [3, {x:1}]

  """
  y = 10;
  z = 40;
  function evalLocal() {
    var x = 1;
    return eval('var y = 5; x + y + z')
  }
  evalLocal();
  """: [46, ((global) ->
    expect(global.y).to.eql(10)
  )]

  """
  function evalClosure() {
    var x = 1;
    return eval('(function() { return x++ })')
  }
  c = evalClosure();
  [c(), c(), c()];
  """: [[1, 2, 3], ((global) -> )]

  """
  f = new Function('a,', 'return 5;');
  """: [undefined, ((global) ->
    expect(global.errorThrown.stack).to.be(
      """
      EvalError: Line 1: Unexpected token )
          at <script>:1:8
      """
    )
  )]

  """
  throw new URIError('err')
  """: [undefined, ((global) ->
    expect(global.errorThrown.stack).to.be(
      """
      URIError: err
          at <script>:1:10
      """
    )
  )]

  """
  f = generateFunction();
  function generateFunction() {
    return new Function('a,b', 'throw new URIError(a+b);');
  }
  f('a', 'b')
  """: [undefined, ((global) ->
    expect(global.errorThrown.stack).to.be(
      """
      URIError: ab
          at f (<eval>:2:10)
          at <script>:5:0
      """
    )
  )]

  """
  f = generateFunction();
  function generateFunction() {
    return new Function('a,b', 'c', 'd,e',
    'return [a+b+c+d+e, Array.prototype.slice.call(arguments)];');
  }
  f(1, 2, 3, 4, 5);
  """: [[15, [1,2,3,4,5]], ((global) -> )]

  'eval("(")': [undefined, ((global) -> )]
  '(function(a) { return a })(4)': [4]

  # property descriptors
  """
  (function() {
    var obj, l, k;
    obj = {i: 0};
    o = {}
    Object.defineProperty(obj, 'prop1', {
      get: function() { return ++this.i; },
      set: function(val) { this.i = val + 10; },
      enumerable: true
    });
    Object.defineProperty(obj, 'prop2', {
      value: 'val',
    });
    Object.defineProperty(o, 'prop3', {
      value: 5,
      writable: true,
      configurable: true,
      enumerable: true
    });
    obj.prop2 = 'val2';
    l = [obj.prop2, delete obj.prop2];
    l.push(obj.prop2);
    l.push(obj.prop1);
    l.push(obj.prop1);
    obj.prop1 = 3;
    l.push(obj.prop1);
    l.push(obj.prop1);
    for (k in obj) l.push(k);
    return l;
  })();
  """: [['val', false, 'val', 1, 2, 14, 15, 'i', 'prop1'], {o: {prop3: 5}}]
}

merge = {
  Dog: class Dog
    bark: -> @barked = true
  console: console
  log: -> console.log.apply(console, arguments)
}

startIndex = 0
stopIndex = 1210

vmEvalSuite = (description, init, testInit, getResult) ->
  describe description, ->
    before(init)
    beforeEach(testInit)

    i = 0

    for own k, v of tests
      if i == stopIndex
        break
      if i >= startIndex
        do (k, v) ->
          fn = ->
            try
              result = getResult.call(this, k)
            catch e
              # console.log e.stack
              err = e
            expect(result).to.eql expectedValue
            if typeof expectedGlobal == 'function'
              @global.errorThrown = err
              expectedGlobal(@global)
            else
              if err
                throw new Error("The VM has thrown an error:\n#{err}")
              if typeof expectedGlobal == 'object'
                expect(strip(@global)).to.eql expectedGlobal
              else
                expect(strip(@global)).to.eql {}

            # assert builtin properties are not tampered by the self-hosted vm
          test = "\"#{k}\""
          expectedValue = v[0]
          expectedGlobal = v[1]
          if 1 in [expectedGlobal, v[2]] then it.only(test, fn)
          else if 0 in [expectedGlobal, v[2]] then it.skip(test, fn)
          else it(test, fn)
      i++

if selftest
  vmEvalSuite 'self-hosted vm eval', ->
    compiledVm = Vm.fromJSON(JSON.parse(
      JSON.stringify(Vm.compile(vmjs, 'vm.js').toJSON())))
    @vm = new Vm(merge, true)
    @vm.run(compiledVm)
  , ->
    @vm.eval("vm = new Vm({Dog: Dog}, true);")
    @global = @vm.realm.global.vm.realm.global
  , (string) ->
    @vm.realm.global.vm.eval(string)

if nativetest
  vmEvalSuite 'vm eval', ->
    @vm = null
  , ->
    @vm = new Vm(merge, true)
    @global = @vm.realm.global
  , (string) ->
    # implicitly test script serialization/deserialization
    script = Vm.fromJSON(JSON.parse(
      JSON.stringify(Vm.compile(string).toJSON())))
    @vm.run(script)


describe 'API', ->
  vm = null

  beforeEach ->
    vm = new Vm()

  it 'call vm functions directly', ->
    code =
      """
      function fn() {
        return this._id++;
      }

      _id = 10;

      idGen = {
        _id: 1,
        id: fn
      };
      """
    vm.eval(code)
    glob = vm.realm.global
    idGen = glob.idGen
    expect([glob.fn(), glob.fn(), glob.fn()]).to.eql([10, 11, 12])
    expect([idGen.id(), idGen.id(), idGen.id()]).to.eql([1, 2, 3])

  it 'fiber pause/resume', (done) ->
    fiber = vm.createFiber(Vm.compile('x = 1; x = asyncArray(); x.pop()'))
    vm.realm.global.asyncArray = ->
      fiber.pause()
      expect(vm.realm.global.x).to.eql(1)
      setTimeout ->
        rv = [1, 2, 3]
        fiber.setReturnValue(rv)
        expect(fiber.resume()).to.eql(3)
        expect(vm.realm.global.x).to.eql(rv)
        expect(rv).to.eql([1, 2])
        done()
    fiber.run()

  it 'instruction timeout', ->
    code =
    """
    i = 0
    infiniteLoop();
    function infiniteLoop() {
      while (true) i++
    }
    """
    try
      vm.eval(code, '<timeout>', 500)
    catch e
      fiber = e.fiber
      expect(e.stack).to.eql(
        """
        TimeoutError: Script timed out
            at infiniteLoop (<timeout>:4:15)
            at <timeout>:2:0
        """
      )
      expect(fiber.timedOut()).to.eql(true)
      # the following expectations are not part of the spec
      # (they are here just for demonstration)
      expect(vm.realm.global.i).to.eql(37)
      # resume fiber, giving it a bit more of 'processor' time
      try
        fiber.resume(1000)
      catch e
        expect(e.stack).to.eql(
          """
          TimeoutError: Script timed out
              at infiniteLoop (<timeout>:4:15)
              at <timeout>:2:0
          """
        )
        expect(fiber.timedOut()).to.eql(true)
        expect(vm.realm.global.i).to.eql(114)

  it 'customize recursion depth', ->
    code =
      """
      var i = 0;
      var j = rec();

      function rec() {
        if (i < 1000) {
          i++;
          return rec();
        }
        return i;
      };
      """
    script = Vm.compile(code, 'stackoverflow.js')
    VmError = vm.realm.global.Error
    msg = /^maximum\scall\sstack\ssize\sexceeded$/
    fiber = vm.createFiber(script)
    expect(( -> fiber.run())).to.throwError (e) ->
      expect(e).to.be.a(VmError)
      expect(e.message).to.match(msg)
    expect(vm.realm.global.j).to.eql(undefined)
    # create a new fiber and increase maximum depth by 1
    fiber = vm.createFiber(script)
    fiber.maxDepth += 1
    fiber.run()
    expect(vm.realm.global.j).to.eql(1000)


strip = (global) ->
  # strip builtins for easy assertion of global object state
  delete global.Object
  delete global.Function
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
  delete global.Dog
  delete global.undefined
  delete global.global
  delete global.console
  delete global.parseFloat
  delete global.parseInt
  delete global.eval
  delete global.log
  return global
