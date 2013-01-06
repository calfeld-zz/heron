# Copyright 2010-2012 Christopher Alfeld
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
DU = require( "doundo.js" ).Heron.DoUndo

describe 'Heron.DoUndo', ->
  it 'should start empty', ->
    du = new DU()
    assert.equal( 0, du.actions().length )
    assert.equal( -1, du.location() )

  describe 'did', ->
    du = new DU()
    x = 0
    du.did(
      do:      -> x = 1
      undo:    -> x = -1
      message: 'did message'
    )
    it 'should not do the action', ->
      assert.equal( 0, x )
    it 'should add to the queue', ->
      assert.equal( 1, du.actions().length )
      assert.equal( 'did message', du.action_messages()[0] )
      assert.equal( 0, du.location() )

  describe 'do', ->
    du = new DU()
    x = 0
    du.do(
      do:      -> x = 1
      undo:    -> x = -1
      message: 'do message'
    )
    it 'should do the action', ->
      assert.equal( 1, x )
    it 'should add to the queue', ->
      assert.equal( 1, du.actions().length )

  describe 'undo', ->
    du = new DU()
    x = 0
    du.do(
      do:      -> x = 1
      undo:    -> x = -1
      message: 'undo message'
    )
    du.undo()
    it 'should undo the action', ->
      assert.equal( -1, x )
    it 'should move the queue earlier', ->
      assert.equal( -1, du.location() )
    it 'should not clear the queue', ->
      assert.equal( 1, du.actions().length )

  describe 'redo', ->
    du = new DU()
    x = 0
    du.do(
      do:      -> x = 1
      undo:    -> x = -1
      message: 'redo message'
    )
    du.undo()
    du.redo()
    it 'should redo the action', ->
      assert.equal( 1, x )
    it 'should move the queue later', ->
      assert.equal( 0, du.location() )
    it 'should not clear the queue', ->
      assert.equal( 1, du.actions().length )

  describe 'do_after_undo', ->
    du = new DU()
    x = 0
    du.do(
      do:      -> x = 1
      undo:    -> x = -1
      message: 'dau message'
    )
    du.undo()
    du.do(
      do:      -> x = 2
      undo:    -> x = -2
      message: 'dau message 2'
    )
    it 'should lose the original', ->
      assert.equal( 1, du.actions().length )
      assert.equal( 'dau message 2', du.action_messages()[0] )
    it 'should be done', ->
      assert.equal( 2, x )

  describe 'reset', ->
    du = new DU()
    x = 0
    du.do(
      do:      -> x = 1
      undo:    -> x = -1
      message: 'clear message'
    )
    du.reset()
    it 'should clear the queue', ->
      assert.equal( 0, du.actions().length )
    it 'should reset the location', ->
      assert.equal( -1, du.location() )
