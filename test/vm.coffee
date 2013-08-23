Vm = require '../src/vm'

tests = {
  ## expressions
  # literals
  "({name: 'thiago', 'age': 28, 1: 2})": [{name: 'thiago', age: 28, 1: 2}]
  "[1, 2, [1, 2]]": [[1, 2, [1, 2]]]
  "'abc'": ['abc']
  "/abc/gi === /abc/gi": [false]
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
  # other acceptance tests
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
    expect(global.l).to.deep.eql([[1, 3, 5], [1, 3, 6], [1, 4, 5], [1, 4, 6],
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
    expect(global.l).to.deep.eql([[1, 3, 5], [1, 3, 6], [1, 4, 5], [1, 4, 6],
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
    expect('i' of global).to.be.false
    expect('k' of global).to.be.false
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
    expect(global.l).to.deep.eql([[1, 3, 5]])
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
    expect(global.l).to.deep.eql([[1, 3, 5], [2, 3, 5]])
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
    expect(global.l).to.deep.eql([[1, 3, 5], [2, 3, 5]])
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
    expect(global.l).to.deep.eql([[1, 3, 5], [1, 4, 5], [2, 3, 5], [2, 4, 5]])
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
    expect('y' of global).to.be.false)]

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
  """: [undefined, ((global) ->
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
  """: [undefined, ((global) ->
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
  """: [undefined, ((global) ->
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
  """: [undefined, ((global) ->
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
    expect('k' of global).to.be.false
    expect('i' of global).to.be.false
    expect('j' of global).to.be.false
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
    expect(global.l).to.deep.eql([1, 2, 3])
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
  """: [[new Number(1), new Number(null), new Number(undefined)]]

  """
  [new Boolean(1), new Boolean(null), new Boolean(undefined)]
  """: [[new Boolean(1), new Boolean(null), new Boolean(undefined)]]

  """
  dog = new Dog()
  dog.bark()
  """: [true, ((global) ->
    expect(global.dog).to.be.instanceof(merge.Dog)
    expect(global.dog.barked).to.be.true
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
    expect('custom' of Object.prototype).to.be.false
  )]

  """
  i = 1
  Object.prototype.bark = function() { return 'bark' + i++ };
  [({}).bark(), [].bark(), new Date().bark()]
  """: [['bark1', 'bark2', 'bark3'], ((global) ->
    expect('bark' of Object.prototype).to.be.false
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
    expect(global.p1).to.be.instanceof(global.Person)
    expect(global.p1str).to.eql('[object Object]')
    expect(global.p1name).to.eql('john doe')
    expect(global.p2name).to.eql('employee: thiago arruda')
    expect(global.p3name).to.eql('employee: programmer: linus torvalds')
  )]

}

merge = {
  Dog: class Dog
    bark: -> @barked = true
}


describe 'vm eval', ->
  vm = null

  beforeEach ->
    vm = new Vm(merge)
    vm.realm.registerNative(merge.Dog.prototype)

  for own k, v of tests
    do (k, v) ->
      fn = ->
        try
          result = vm.eval(k)
        catch e
          err = e
        expect(result).to.deep.eql expectedValue
        if typeof expectedGlobal is 'function'
          vm.realm.global.errorThrown = err
          expectedGlobal(vm.realm.global)
        else
          if err
            throw new Error("The VM has thrown an error:\n#{err}")
          if typeof expectedGlobal is 'object'
            expect(strip(vm.realm.global)).to.deep.eql expectedGlobal
          else
            expect(strip(vm.realm.global)).to.deep.eql {}
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
    delete global.Dog
    delete global.undefined

    return global

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
    expect([glob.fn(), glob.fn(), glob.fn()]).to.deep.eql([10, 11, 12])
    expect([idGen.id(), idGen.id(), idGen.id()]).to.deep.eql([1, 2, 3])

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
        expect(rv).to.deep.eql([1, 2])
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
            at infiniteLoop (<timeout>:4:9)
            at <timeout>:2:0
        """
      )
      expect(fiber.timedOut()).to.be.true
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
              at infiniteLoop (<timeout>:4:9)
              at <timeout>:2:0
          """
        )
        expect(fiber.timedOut()).to.be.true
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
    expect(( -> fiber.run())).to.throw(VmError, msg)
    expect(vm.realm.global.j).to.be.undefined
    # create a new fiber and increase maximum depth by 1
    fiber = vm.createFiber(script)
    fiber.maxDepth += 1
    fiber.run()
    expect(vm.realm.global.j).to.eql(1000)


