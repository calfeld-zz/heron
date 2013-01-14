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
V = require( "../vector.js" ).Heron.Vector

# Assert that a and b are within 0.001 of each other.
assert_float = ( a, b ) ->
	delta = Math.abs( a - b )
	assert.isTrue( delta < 0.001, "expected difference to be small but was: #{delta}")

describe 'Heron.Geometry', ->

	describe 'vec2', ->
		it 'should create the origin', ->
			a = V.vec2( )
			assert.equal( 0, a[0] )
			assert.equal( 0, a[1] )
		it 'should create its arguments', ->
			a = V.vec2( 1, 2 )
			assert.equal( 1, a[0] )
			assert.equal( 2, a[1] )

	describe 'dup2', ->
		a = V.vec2( 1, 2 )
		b = V.dup2( a )
		it 'should create an identical vector', ->
			assert.equal( a[0], b[0] )
			assert.equal( a[1], b[1] )
		it 'should create a different object', ->
			a[0] = 5
			assert.notEqual( a[0], b[0] )

	describe 'equal2', ->
		a = V.vec2( 1, 2 )
		it 'should differentiate different vectors', ->
			b = V.vec2( 3, 4 )
			assert.isFalse( V.equal2( a, b ) )
		it 'should be true for the same object', ->
			assert.isTrue( V.equal2( a, a ) )
		it 'should be true for different but identical vectors', ->
			assert.isTrue( V.equal2( a, V.dup2( a ) ) )

	describe 'set2', ->
		a = V.vec2( 1, 2 )
		c = V.set2( a, 7, 8 )
		it 'should overwrite the first argument', ->
			assert.equal( a[0], 7 )
			assert.equal( a[1], 8 )
		it 'should return the first argument', ->
			assert.equal( a, c )

	describe 'add2', ->
		a = V.vec2( 1, 2 )
		b = V.vec2( 8, 10 )
		c = V.add2( a, b )
		it 'should add to the first argument', ->
			assert.equal( a[0], 9 )
			assert.equal( a[1], 12 )
		it 'should not modify the second argument', ->
			assert.equal( b[0], 8 )
			assert.equal( b[1], 10 )
		it 'should return the first argument', ->
			assert.equal( a, c )

	describe 'sub2', ->
		a = V.vec2( 1, 2 )
		b = V.vec2( 8, 10 )
		c = V.sub2( a, b )
		it 'should subtract from the first argument', ->
			assert.equal( a[0], -7 )
			assert.equal( a[1], -8 )
		it 'should not modify the second argument', ->
			assert.equal( b[0], 8 )
			assert.equal( b[1], 10 )
		it 'should return the first argument', ->
			assert.equal( a, c )

	describe 'dot2', ->
		it 'should calculate the dot product', ->
			assert.equal( V.dot2( V.vec2( 1, 2 ), V.vec2( 3, 4 ) ), 11 )

	describe 'negate2', ->
		a = V.vec2( 1, 2 )
		b = V.negate2( a )
		it 'should negative its argument', ->
			assert.equal( a[0], -1 )
			assert.equal( a[1], -2 )
		it 'should return its argument', ->
			assert.equal( a, b )

	describe 'length2', ->
		it 'should calculate the length of a vector', ->
			assert_float( V.length2( V.vec2( 3, 4 ) ), 5 )

	describe 'normalize2', ->
		a = V.vec2( 3, 4 )
		b = V.normalize2( a )
		it 'should normalize each coordinate', ->
			assert_float( a[0], 3/5 )
			assert_float( a[1], 4/5 )
		it 'should make a vector of length 1', ->
			assert_float( V.length2( a ), 1 )
		it 'should return its argument', ->
			assert.equal( a, b )

	describe "to_s2", ->
		it 'should turn a vector into a string', ->
			assert.equal( V.to_s2( V.vec2( 1, 2 ) ), "(1, 2)")

	describe "normal2", ->
		a = V.vec2( 1, 2 )
		b = V.normal2( a )
		it 'should swap/negate its arguments coordinates', ->
			assert.equal( a[0], 2 )
			assert.equal( a[1], -1 )
		it 'should return its argument', ->
			assert.equal( a, b )
