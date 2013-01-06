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

Heron = @Heron ?= {}

# Assert that every key in `keys...` is in `obj`.
assert_members = ( obj, keys... ) ->
  for k in keys
    if ! obj[ k ]?
      throw "Missing key: #{k}"

# Shallow copy of `obj`.
clone = ( obj ) ->
  r = {}
  for own k, v of obj
    r[k] = v
  r

# DoUndo manager.
#
# DoUndo maintains a queue of *actions* representing a sequence of steps to
# arrive at the current state from an initial state.  It supports methods to
# add actions to this queue; to undo an action, moving earlier in the queue;
# and to redo an undone action, moving later in the queue.
#
# Specifically, DoUndo tracks a queue and a location in the queue.  Initially,
# the queue is empty and the location undefined.  When the first aciton is
# performed the queue holds that action and the location points to this sole
# element.  Then...
#
# - When an action is performed, all elements after the current location are
#   dropped and the new action is appended.  The location points to the end of
#   the queue.
# - When an action is undone, the location is moved one earlier.
# - When an action is redone, the location is moved one later.
#
# In particular, undoing a bunch of actions and then doing (vs. redoing) a
# new action will cause history to be dropped.  Further undo/redo will work
# on the new action rather than the older actions.  I.e., history is linear
# not a tree.
#
# An action is a function to perform it (`do`), an function to perform the
# reverse (`undo`), and an optional message (`message`).
#
# @author Christopher Alfeld (calfeld@calfeld.net)
# @copyright 2013 Christopher Alfeld
class Heron.DoUndo
  # Constructor.
  #
  # @param [Object] config Configuration.
  # @option config [Function or true] If specified, will emit debug messages
  #   via the function which should a type and message string.  If set to
  #   true, will use `console.log`.  Default: nil.
  # @option on_do [Function] Function to call with action when action is
  #   done.  Default: nil.
  # @option on_undo [Function] Function to call with action when action is
  #   undone.  Default: nil.
  # @option on_redo [Function] Function to call with action when action is
  #   redone.  Default: nil.
  constructor: ( config = {} ) ->
    @_ = {}
    @reset()

    if config.debug? && config.debug == true
      config.debug = ( event_name, msg ) -> console.log( event_name, msg )

    @_.debug   = config.debug
    @_.on_do   = config.on_do
    @_.on_undo = config.on_undo
    @_.on_redo = config.on_redo

  # Report `action` as just performed.
  #
  # Use this when you do an action yourself and want to append it to the
  # queue.
  #
  # @see #do
  #
  # @param [Object] action Must define `do` and `undo`; may define `message`.
  # @return [Heron.DoUndo] this
  did: ( action ) ->
    assert_members( action, 'do', 'undo' )

    # Clear queue from current to end
    if @_.current == -1
      @_.queue = []
    else
      @_.queue = @_.queue[0..@_.current]

    action = clone( action )
    action.message ?= "No message"

    @_.queue.push( action )

    @_.current += 1

    throw "Insanity: Queue length." if @_.current != @_.queue.length - 1

    @_.on_do?( action )
    @_.debug?( 'do', action.message )

    this

  # Perform an action.
  #
  # Equivalent to calling `action.do()` and then {#did}.
  #
  # @param [Object] action Must define `do` and `undo`; may define `message`.
  # @return [Heron.DoUndo] this
  do: ( action ) ->
    action.do()
    @did( action )

    this

  # Undo action at current location in queue and move one action earlier.
  #
  # @throw [String] if {#can_undo} is false.
  # @return [Heron.DoUndo] this
  undo: ->
    throw "Asked to undo, but can't." if ! @can_undo()

    action = @_.queue[ @_.current ]
    action.undo()
    @_.current -= 1

    @_.on_undo?( action )
    @_.debug?( 'undo', action.message )

    this

  # Redo action at next location in queue and move on action later.
  #
  # @throw [String] if {#can_redo} is false.
  # @return [Heron.DoUndo] this.
  redo: ->
    throw "Asked to redo, but can't." if ! @can_redo()

    action = @_.queue[ @_.current + 1 ]
    action.do()

    @_.current += 1

    @_.on_redo?( action )
    @_.debug?( 'redo', action.message )

    this

  # Clear queue.
  #
  # @return [Heron.DoUndo] this
  reset: ->
    @_.queue   = []
    @_.current = -1
    this

  # True iff there is an action available to undo.
  #
  # @return [Boolean] Undo allowed.
  can_undo: ->
    @_.current > -1

  # True iff there is an action available to redo.
  #
  # @return [Boolean] Redo allowed.
  can_redo: ->
    @_.current < @_.queue.length - 1

  # Access queue.
  #
  # @return [Array<Object>] All actions in order.
  actions: ->
    @_.queue

  # Access current action.
  #
  # @return [Numeric] Current location in queue.
  location: ->
    @_.current

  # Accesss queue as messages.
  #
  # @return [Array<String>] All action messages in order.
  action_messages: ->
    action.message for action in @_.queue
