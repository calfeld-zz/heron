// Generated by CoffeeScript 1.6.3
(function() {
  var V, assert, assert_float;

  assert = require('chai').assert;

  V = require('../vector.js').Heron.Vector;

  assert_float = function(a, b) {
    var delta;
    delta = Math.abs(a - b);
    return assert.isTrue(delta < 0.001, 'expected difference to be small but was: #{delta}');
  };

  describe('Heron.Geometry', function() {
    describe('vec2', function() {
      it('should create the origin', function() {
        var a;
        a = V.vec2();
        assert.equal(0, a[0]);
        return assert.equal(0, a[1]);
      });
      return it('should create its arguments', function() {
        var a;
        a = V.vec2(1, 2);
        assert.equal(1, a[0]);
        return assert.equal(2, a[1]);
      });
    });
    describe('dup2', function() {
      var a, b;
      a = V.vec2(1, 2);
      b = V.dup2(a);
      it('should create an identical vector', function() {
        assert.equal(a[0], b[0]);
        return assert.equal(a[1], b[1]);
      });
      return it('should create a different object', function() {
        a[0] = 5;
        return assert.notEqual(a[0], b[0]);
      });
    });
    describe('equal2', function() {
      var a;
      a = V.vec2(1, 2);
      it('should differentiate different vectors', function() {
        var b;
        b = V.vec2(3, 4);
        return assert.isFalse(V.equal2(a, b));
      });
      it('should be true for the same object', function() {
        return assert.isTrue(V.equal2(a, a));
      });
      return it('should be true for different but identical vectors', function() {
        return assert.isTrue(V.equal2(a, V.dup2(a)));
      });
    });
    describe('set2', function() {
      var a, c;
      a = V.vec2(1, 2);
      c = V.set2(a, 7, 8);
      it('should overwrite the first argument', function() {
        assert.equal(a[0], 7);
        return assert.equal(a[1], 8);
      });
      return it('should return the first argument', function() {
        return assert.equal(a, c);
      });
    });
    describe('add2', function() {
      var a, b, c;
      a = V.vec2(1, 2);
      b = V.vec2(8, 10);
      c = V.add2(a, b);
      it('should add to the first argument', function() {
        assert.equal(a[0], 9);
        return assert.equal(a[1], 12);
      });
      it('should not modify the second argument', function() {
        assert.equal(b[0], 8);
        return assert.equal(b[1], 10);
      });
      return it('should return the first argument', function() {
        return assert.equal(a, c);
      });
    });
    describe('sub2', function() {
      var a, b, c;
      a = V.vec2(1, 2);
      b = V.vec2(8, 10);
      c = V.sub2(a, b);
      it('should subtract from the first argument', function() {
        assert.equal(a[0], -7);
        return assert.equal(a[1], -8);
      });
      it('should not modify the second argument', function() {
        assert.equal(b[0], 8);
        return assert.equal(b[1], 10);
      });
      return it('should return the first argument', function() {
        return assert.equal(a, c);
      });
    });
    describe('dot2', function() {
      return it('should calculate the dot product', function() {
        return assert.equal(V.dot2(V.vec2(1, 2), V.vec2(3, 4)), 11);
      });
    });
    describe('negate2', function() {
      var a, b;
      a = V.vec2(1, 2);
      b = V.negate2(a);
      it('should negative its argument', function() {
        assert.equal(a[0], -1);
        return assert.equal(a[1], -2);
      });
      return it('should return its argument', function() {
        return assert.equal(a, b);
      });
    });
    describe('length2', function() {
      return it('should calculate the length of a vector', function() {
        return assert_float(V.length2(V.vec2(3, 4)), 5);
      });
    });
    describe('normalize2', function() {
      var a, b;
      a = V.vec2(3, 4);
      b = V.normalize2(a);
      it('should normalize each coordinate', function() {
        assert_float(a[0], 3 / 5);
        return assert_float(a[1], 4 / 5);
      });
      it('should make a vector of length 1', function() {
        return assert_float(V.length2(a), 1);
      });
      return it('should return its argument', function() {
        return assert.equal(a, b);
      });
    });
    describe('normal2', function() {
      var a, b;
      a = V.vec2(1, 2);
      b = V.normal2(a);
      it('should swap/negate its arguments coordinates', function() {
        assert.equal(a[0], 2);
        return assert.equal(a[1], -1);
      });
      return it('should return its argument', function() {
        return assert.equal(a, b);
      });
    });
    describe('normalb2', function() {
      var a, b;
      a = V.vec2(1, 2);
      b = V.normalb2(a);
      it('should swap/negate its arguments coordinates', function() {
        assert.equal(a[0], -2);
        return assert.equal(a[1], 1);
      });
      return it('should return its argument', function() {
        return assert.equal(a, b);
      });
    });
    describe('angle2', function() {
      it('should give the angle between vector and origin', function() {
        var a, phi;
        a = V.vec2(1, 1);
        phi = V.angle2(a);
        return assert.equal(Math.PI / 4, phi);
      });
      it('should work with x-axis', function() {
        var a, phi;
        a = V.vec2(1, 0);
        phi = V.angle2(a);
        return assert.equal(0, phi);
      });
      return it('should work with y-axis', function() {
        var a, phi;
        a = V.vec2(0, 1);
        phi = V.angle2(a);
        return assert.equal(Math.PI / 2, phi);
      });
    });
    describe('multiply2', function() {
      var a, b, m;
      a = V.vec2(2, 3);
      m = [[2, 3], [5, 7]];
      b = V.multiply2(a, m);
      it('should multiply a vector by a matrix', function() {
        assert.equal(a[0], 19);
        return assert.equal(a[1], 27);
      });
      return it('should return its argument', function() {
        return assert.equal(a, b);
      });
    });
    describe('rotate2', function() {
      var a, b;
      a = V.vec2(4, 2);
      b = V.rotate2(a, Math.PI / 2);
      it('should rotate a vector', function() {
        assert.equal(a[0], 2);
        return assert.equal(a[1], -4);
      });
      return it('should return its argument', function() {
        return assert.equal(a, b);
      });
    });
    describe('scale2', function() {
      var a, b;
      a = V.vec2(3, 5);
      b = V.scale2(a, 2);
      it('should scale a vector', function() {
        assert.equal(a[0], 6);
        return assert.equal(a[1], 10);
      });
      return it('should return its argument', function() {
        return assert.equal(a, b);
      });
    });
    return describe('to_s2', function() {
      return it('should turn a vector into a string', function() {
        return assert.equal(V.to_s2(V.vec2(1, 2)), '(1, 2)');
      });
    });
  });

}).call(this);
