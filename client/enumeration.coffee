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

if module? && module.exports
  Heron.Util = require('util.js').Heron.Util

# Variable with enumerated domain.
#
# Variable that takes value from a list of provided values.  Supports
# for advancing to next or previous value and for cyclic domains.
#
# @author Christopher Alfeld (calfeld@calfeld.net)
# @copyright 2013 Christopher Alfeld
class Heron.Enumeration
  # Constructor.
  #
  # @param [Object] config Configuration.
  # @option config [List<Object>] values Possible values of variable.
  #   Required.
  # @option config [Boolean] cycle If true, advancing past bondary will loop.
  #   If false, advancing past boundary will stick to boundary.
  #   Default: false.
  # @option config [Integer] index Index of initial value; default to 0.
  constructor: ( config = {} ) ->
    @_ =
      values:  config.values      ? throw "values required."
      cycle:   config.cycle       ? false
      on_set:  jQuery.Callbacks()
      index:   config.index ? 0

  # Set value by index.
  #
  # If index is out of range, will be adjusted according to cycle setting.
  # See {#i}.
  #
  # @param [Integer] index Index to set to.
  # @return New value.
  set_index: ( index ) ->
    if index != @_.index
      @_.index = @i( index )
      @on_set( @value(), index )
    @value

  # Set value by value.
  #
  # @param [Object] value Value to set to.
  # @return New value.
  # @throw if `value` not in values.
  set_value: ( value ) ->
    i = @values().indexOf( value )
    if i == -1
      throw "Value not found"
    else
      return set_index( i )

  # Current index.
  #
  # @return [Integer] Current index.
  index: ->
    @_.index

  # Values.
  #
  # @return [List<Object>] Values.
  values: ->
    @_.values

  # Current value.
  #
  # @return [Object] Current value.
  value: ->
    @values()[@index()]

  # Number of values.
  #
  # @return [Integer] Number of values.
  length: ->
    @values().length

  # Does this value cycle?
  #
  # @return [Bool] true iff cycled enumeration.
  cycle: ->
    @_.cycle

  # Adjust index to be in range [0, length - 1].
  #
  # If cycle is true, indices out of range will loop.  If cycle is false,
  # indices out of range will go to nearest boundary.  In both cases, negative
  # indices are allowed.  Example: If length is 4, an index of 6 will be
  # mapped to 2 on cycle and 3 on no-cycle; a length of -1 will be mapped to
  # 3 on cycle and 0 on no-cycle.
  #
  # @param [Integer] index Index to adjust.
  # @return [Integer] Index in range [0, length - 1].
  i: ( index ) ->
    l = @length()
    if @_.cycle
      # index % l gives [ -l + 1, l - 1]
      # above + l gives [ 0, 2l - 1]
      # above % l gives [ 0, l - 1]
      ( ( index % l ) + l ) % l
    else
      Math.max( Math.min( index, 0 ), l - 1 )

  # Increment index by `n`.
  #
  # @param [Integer] n Amount to increment by.  Negative allowed.
  #   Default: 1.
  # @return [Object] New value.
  incr: ( n = 1 ) ->
    s = size()
    @set_index( @i( @index + n ) )

  # Alias for `@incr(-1 * n)`.
  #
  # @param [Integer] n Amount to decrement by.  Negative allowed.
  #   Default: 1.
  # @return [Object] New value.
  decr: ( n = 1 ) ->
    @incr( -1 * n )

  # Register callback for when value is set.
  #
  # Multiple callbacks can be registered by calling multiple times.  Will not
  # be called if value is set to current value.
  #
  # @param [Function(Object)] f Function to call when value is set.  Passed
  #   value and index.
  # @return [Heron.Enumeration] this
  on_set: ( f ) ->
    @_.on_set.add( f )
    this
