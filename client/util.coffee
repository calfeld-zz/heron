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

# Table that {generate_id} uses.
c_generate_id_table = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

# Miscalaneous Utilities
#
# This file contains routines used by much other Heron code that do simple
# common tasks.
#
# @author Christopher Alfeld (calfeld@calfeld.net)
# @copyright 2012 Christopher Alfeld
class Heron.Util

  # Generate random number.
  #
  # @return [integer] Random number in [0, n)
  @rand = ( n ) ->
    Math.floor( Math.random() * n )

  # Generate random identifier.
  #
  # @param [integer] n Length of identifier.
  # @return [string] Random string of length n.
  @generate_id = ( n = 8 ) ->
    l = c_generate_id_table.length
    ( c_generate_id_table[ @rand( l ) ] for i in [0..n-1] ).join( '' )

  # Return keys of an object.
  #
  # @param [object] obj Object to list keys of.
  # @return [array<string>] List of keys in `obj`.
  @keys = ( obj ) ->
    for own k of obj
      k

  # Add members of `mixin` to obj.
  #
  # Use to mixin class members.
  #
  # See The Little Book on CoffeeScript.  But not differences.
  #
  # @param [Object] obj   Object to mix into.
  # @param [Object] mixin Mixin to mix in.
  # @return [Object] obj
  @extend = (obj, mixin) ->
    for name, method of mixin
      obj[name] = method if ! obj[name]?
    obj

  # Add member of `mixin` to prototype of `klass`.
  #
  # Use to mixin instance members.
  #
  # See The Little Book on CoffeeScript.
  #
  # @param [Object] klass Object to mix into.
  # @param [Object] mixin Mixin to mix in.
  # @return [Object] klass
  @include = (klass, mixin) ->
    @extend klass.prototype, mixin

  # True iff object has no members.
  #
  # @param [Object] object
  # @return [Boolean] true iff object is empty.
  @empty = (object) ->
    for k of object
      return false
    true

  # Return a [key, value] of object.
  #
  # @param [Object] object
  # @return [Array<String,Object>] A key and value of object.
  @any = (object) ->
    for k, v of object
      return [k, v]

