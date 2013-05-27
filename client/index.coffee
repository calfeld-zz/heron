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

# Collection of objects indexed by one or more keys.
#
# An index is constructed with one or more keys and extractors defined.  For
# each key, it provides methods to easily access entries by key.  Objects can
# then be added to the index, and the extractors will be used to determine
# the key values for each key.
#
# @method #each_K( f )
#   Call `f(v)` for each value `v` of key `K`.
#   @param [Function] f Function to call.
#   @return [Array<any>] Return values of `f`.
#
# @method #with_K( v )
#   All items with value `v` of key `K`.
#   @param [String] v Value of key `K` to look for keys of.
#   @return [Array<any>] Objects with value `v` of key `K`.
#
# @see Heron.Index.ObjectIndex
# @see Heron.Index.MapIndex
#
# @author Christopher Alfeld (calfeld@calfeld.net)
# @copyright 2010-2013 Christopher Alfeld
class Heron.Index

  # Constructor.
  #
  # @param [Object] extractors Keys and their extractors.  Extractors should
  #   take an object and return the key value, as a string.
  constructor: (extractors) ->
    @_ =
      extractors: extractors
      indices:    {}

    for k of extractors
      do (k) =>
        @_.indices[k] = {}
        this["each_#{k}"] = (f = (x) -> x) ->
          f(v) for v of @_.indices[k]
        this["with_#{k}"] = (value) ->
          @_.indices[k][value] ? []

  # Add an object to the index.
  #
  # Adding an object already added will have no effect.
  #
  # @param [Object] obj Object to add.
  # @return [Heron.Index] this
  add: (obj) ->
    for k, e of @_.extractors
      v = e(obj)
      (@_.indices[k][v] ?= []).push(obj)
    this

  # Remove an object from the index.
  #
  # Removing an object not in index will have no effect.
  #
  # @param [Object] obj Object to remove.
  # @return [Heron.Index] this
  remove: (obj) ->
    for k, e of @_.extractors
      v = e(obj)
      if @_.indices[k][v]?
        new_index = []
        for other in @_.indices[k][v]
          if obj != other
            new_index.push(other)
        @_.indices[k][v] = new_index
        if Heron.Util.empty(@_.indices[k][v])
          delete @_.indices[k][v]
    this

  # Iterate through every object in index.
  #
  # Note that calling without an argument returns an array of every
  # object.
  #
  # @param [Function] f Function to call on every object.  Defaults to
  #   identity.
  # @return [Array<Object>] Returns values of `f` for each object in index.
  each: (f = (x) -> x) ->
    r = []
    index = Heron.Util.any(@_.indices)[1]
    for v, objs of index
      for obj in objs
        r.push(f(obj))
    r

  # Is the index empty?
  #
  # @return [Boolean] True iff there is an object in the index.
  empty: ->
    for k, i of @_.indices
      for v of i
        return false
    return true

# Specialization of {Heron.Index} for objects.
#
# This index takes an array of key names on construction and pulls values
# directly out of the object.  That is, for an object `O` and key `K`, the
# value is extracted as `O[K]`.
#
# @author Christopher Alfeld (calfeld@calfeld.net)
# @copyright 2010-2013 Christopher Alfeld
class Heron.Index.ObjectIndex extends Heron.Index

  # Constructor.
  #
  # @param [Array<String>] keys... Keys to index.
  constructor: (keys...) ->
    extractors = {}
    for k in keys
      do (k) ->
        extractors[k] = (obj) -> obj[k]
    super extractors

# Specialization of {Heron.Index} for {Heron.Map}.
#
# This index takes an array of key names on construction and pulls values out
# using the {Heron.Map} interface.  That is, for an object `O` and key `K`,
# the value is extracted as `O.gets(K)`.
#
# @author Christopher Alfeld (calfeld@calfeld.net)
# @copyright 2010-2013 Christopher Alfeld
class Heron.Index.MapIndex extends Heron.Index

  # Constructor.
  #
  # @param [Array<String>] keys... Keys to index.
  constructor: (keys...) ->
    extractors = {}
    for k in keys
      do (k) ->
        extractors[k] = (obj) -> obj.gets(k)
    super extractors





