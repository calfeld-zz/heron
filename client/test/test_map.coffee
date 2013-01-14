# Copyright 2010-2013 Christopher Alfeld
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

assert = require( "chai" ).assert
M = require( "map.js" ).Heron.Map

describe 'Heron.Map', ->
  describe 'ObjectMap', ->
    describe 'constructor', ->
      it 'should support no arguments', ->
        assert.deepEqual( {}, new M.ObjectMap().get() )
      it 'should support an object', ->
        obj = foo: 'bar'
        assert.deepEqual( obj, new M.ObjectMap( obj ).get())
    obj =
      foo: 'bar'
      baz: 'buz'
      hello: 'world'
    map = new M.ObjectMap( obj )
    describe 'get', ->
      it 'should return the keys asked for', ->
        result = map.get( 'foo', 'baz' )
        assert.equal( obj.foo, result.foo )
        assert.equal( obj.baz, result.baz )
    describe 'gets', ->
      it 'should return the value of the key asked for', ->
        assert.equal( obj.foo, map.gets( 'foo' ) )
    describe 'geta', ->
      it 'should return an array of values of the keys asked for', ->
        assert.deepEqual( [ obj.foo, obj.baz ], map.geta( 'foo', 'baz' ) )
    describe 'keys', ->
      it 'should return the keys of the map', ->
        k = map.keys()
        assert.equal( 3, k.length )
        assert.notEqual( -1, k.indexOf( 'baz' ) )
        assert.notEqual( -1, k.indexOf( 'foo' ) )
        assert.notEqual( -1, k.indexOf( 'hello' ) )
    describe 'set', ->
      o = foo: 'baz'
      m = new M.ObjectMap( o )
      it 'should change the value', ->
        m.set( foo: 'buz' )
        assert.equal( 'buz', m.gets( 'foo' ) )
      it 'should allow adding a value', ->
        m.set( hello: 'world' )
        assert.equal( 'world', m.gets( 'hello' ) )

  describe 'map', ->
    it 'should turn an object into a map', ->
      obj = foo: 'bar'
      assert.equal( 'bar', M.map( obj ).gets( 'foo' ) )
    it 'should leave a map alone', ->
      map = new M.ObjectMap( foo: 'bar' )
      assert.equal( map, M.map( map ) )

  describe 'ParametricMap', ->
    it 'should return normal values normally', ->
      assert.equal( 'bar', new M.ParametricMap( foo: 'bar' ).gets( 'foo' ) )
    it 'should evlauate function values', ->
      assert.equal( 'bar', new M.ParametricMap( foo: -> 'bar' ).gets( 'foo' ) )
    it 'should recursively evaluate functions.', ->
      assert.equal( 'bar', new M.ParametricMap( foo: -> -> 'bar' ).gets( 'foo' ) )
