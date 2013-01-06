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

# Throw an exception about Heron.Map not being used directly.
map_throw = -> throw "Do not use Heron.Map directly."

# This class/module describes the Heron.Map interface, a set of routines for
# accessing a key-value store.  It serves as documentation of the
# interface and as a class to convert a javascript object to that interface.
#
# Do not try to instantiate Heron.Map.  If you want a map from an object, use
# {Heron.Map.map} or {Heron.Map.ObjectMap}.
#
# The main advantage over a standard javascript object is that all accesses
# pass through a function, allowing computation or side effects.  See, for
# example, {Heron.Map.ParametricMap}.
#
# Any parameter in Heron that asks for a {Heron.Map} is duck typed and asking
# for an object that defines {#get}, {#gets}, {#geta}, {#keys}, and, if it
# needs a writable map, {#set}.
#
# @author Christopher Alfeld (calfeld@calfeld.net)
# @copyright 2013 Christopher Alfeld
class Heron.Map
  # Access keys as object.
  #
  # If called with no arguments, returns an object with all key-value pairs in
  # the map.
  #
  # If called with one or more arguments, interprets the arguments as key
  # names and returns an object with the specified key-value pairs that are
  # present in the map.
  #
  # This method is always allowed to return more keys than are asked for.
  #
  # The return of this method should *not* be modified.
  #
  # @param [String...] keys... Keys to fetch.
  # @return [Object] Keys and values.
  get: ( keys... ) -> map_throw

  # Get value of a single key.
  # @param [String] key Key to fetch.
  # @return [Any] Value of `key`, possibly null.
  gets: ( key ) -> map_throw

  # Get values of keys as array.
  # @param [String...] keys... Keys to fetch.
  # @return [Array<Any>] Values of keys in same order.
  geta: ( key... ) -> map_throw

  # Get keys.
  # @return [Array<String>] All keys in map.
  keys: -> map_throw

  # Set key-values.
  #
  # Adds the specified key-values to the map.
  #
  # This method is only required in writable maps.  Read-only maps do not need
  # to define it.
  #
  # @param [Object] key_values Keys and values to add.
  # @return [Heron.Map] this
  set: ( key_values... ) -> map_throw

  # Ensure that `obj` is a {Heron.Map}.
  #
  # If `obj` has `get`, `gets`, `geta`, and `keys` members, returns `obj`,
  # otherwise returns `new Heron.Map(obj)`.
  #
  # @param [Object] obj Object to ensure is a {Heron.Map}.
  # @return [Heron.Map] A Heron.Map corresponding to `obj`.
  @map: ( obj ) ->
    ok = ( x ) -> obj[x]? && typeof( obj[x] ) == 'function'
    for v in [ 'get', 'gets', 'geta', 'keys' ]
      if ! ok( v )
        return new @ObjectMap( obj )
    obj

# Mixin `gets`, `geta`, and `keys`; all based on `get`.
# @mixin
Heron.Map.Mixin =
  # @see Heron.Map#gets
  gets: ( key ) ->
    @get( key )[ key ]

  # @see Heron.Map#geta
  geta: ( key... ) ->
    values = @get( key... )
    values[ k ] for k in key

  # @see Heron.Map#keys
  keys: ->
    k for k of @get()

# Present an object as a {Heron.Map}.
#
# @include Heron.Map.Mixin
class Heron.Map.ObjectMap
  Heron.Util.include this, Heron.Map.Mixin

  # Construct an object based Heron.Map.
  #
  # Constructs a Heron.Map that simply wraps an object, either the parameter
  # or an empty object.
  #
  # @param [Object] obj Object to wrap.
  constructor: ( obj = {} ) ->
    @_ ?= {}
    @_.obj = obj

  # @see Heron.Map#get
  get: ( keys... ) ->
    @_.obj

  # @see Heron.Map#set
  set: ( key_values ) ->
    for k, v of key_values
      @_.obj[ k ] = v
    this

# Map that interprets function-values on query.
#
# When a value is queried that is a function, that function is called with no
# arguments and the return is treated as the value.  This process is repeated
# until a non-function value results, which is then returned as the value.
#
# The utility of this class is to define a set of key-values where the values
# depend on some external context.  Get operations are viewed as queries
# rather than direct access.
class Heron.Map.ParametricMap extends Heron.Map.ObjectMap
  # As {Heron.Map#keys}.
  keys: ->
    # As @get() is defined in terms of @keys() rather than the opposite, can't
    # use the normal @keys().
    Heron.Util.Keys( @_.obj )

  # Query values.
  #
  # Any function value is evaluated with the return used in its place.
  #
  # See {Heron.Map#get}
  get: ( key... ) ->
    values = super( key... )
    # Not allowed to mutate values, so construct new object.
    result = {}
    for k, v of values
      v = v() while typeof( v ) == 'function'
      result[k] = v
    result
