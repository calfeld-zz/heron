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

# Helper Methods

# Filter keys out of an object and insist all are there.
#
# Will throw an exception if any listed key is not in object.  Will return
# object containing only listed keys.
#
# @param [Object]       obj  Object to assert keys on.
# @param [List<String>] keys List of keys to assert are in `obj`.
# @return [Object] Object containing only keys in `obj` that are listed in
#   `keys`.
# @throw [String] If any key not in object.
only_keys = ( obj, keys ) ->
  result = {}
  for k in keys
    throw "Missing key #{k}" if ! obj[k]?
    result[k] = obj[k]
  result

# Construct subkey name from id and subkey.
#
# @param [String] id     Thingy id.
# @param [String] subkey Subkey name.
# @return [String] Subkey ID.
subkey_key = ( id, subkey ) ->
  "#{id}.#{subkey}"

# Split a key into id and subkey.
#
# @param [String] key Key to split.
# @return [Array<String, String>] Thingy ID and subkey name.
split_key = ( key ) ->
  [ id, rest... ] = key.split( "." )
  [ id, rest.join( "." ) ]

# What follows are implementations of private methods of Heron.Thingy.  These
# must have this properly bound ot a Heron.Thingy instance.  This can be
# easily done by calling them from @_, e.g., @_.send_update_subkey(...).

# Send update message for a single subkey for a thingy.
#
# @param [thingy] thingy Thingy to send update of.
# @param [String] subkey Subkey to send update of.
# @return [null] null
send_update_subkey = ( thingy, subkey ) ->
  # We take advantage that thingy.get is just an alias for the appropriate
  # delegate.get.  In particular, it has no side effects.

  type_data = @_.per_type[ thingy.typename() ]
  attr_names = type_data.subkeys[ subkey ]
  data = only_keys(
    thingy.get( attr_names... ),
    attr_names
  )

  key = subkey_key( thingy.id(), subkey )

  domain = @_.domain

  if subkey == '_'
    data =
      typename: thingy.typename()
      subkeys:  Heron.Util.keys( per_type.subkeys )
      attrs:    data

  @_.dictionary.update( @_.domain, key, data )

  null

# Send create message for a thingy.
#
# @param [thingy] thingy Thingy to send create for.
# @return [null] null
send_create = ( thingy ) ->
  typename  = thingy.typename()
  id        = thingy.id()
  type_data = @_.per_type[ typename ]

  @_.dictionary.batch =>
    for subkey, attr_keys of type_data.subkeys
      key   = subkey_key( id, subkey )
      value = only_keys( thingy.get( attr_keys... ), attr_keys )
      if subkey == '_'
        value =
          typename: typename
          attrs: value
      @_.dictionary.create( @_.domain, key, value )
    # %create tells others to create the thingy.
    @_.dictionary.create( @_.domain, '%create', id )

  null

# Construct a thingy.
#
# @param [String] typename   Name of thingy type.
# @param [String] id         ID.
# @param [Object] attrs      Initial attributes.
# @param [Object] local_data Local data, if any.
# @return [thingy] New thingy.
# @throw [String] If `typename` isn't known.
# @throw [String] If `id` already exists.
make_thingy = ( typename, id, attrs, local_data ) ->
  if ! typename?
    @_.on_error( "Missing typename for thingy: #{id}" )
  @_.make_guard = true
  thingy = new Heron.Thingy( this, typename, id, attrs, local_data )
  @_.make_guard = false
  thingy

# Create all partials.
#
# @return [null] null
flush_partials = ->
  for id, info of @_.partials
    @_.make_thingy( info.typename, id, info.attrs, false )
  @_.partials = {}
  null

# Receiver class.
#
# Private class, not for external use.
#
# @private
class Receiver

  # Constructor.
  #
  # @param [Heron.Thingyverse] thingyverse Thingyverse to use.
  constructor: ( thingyverse ) ->
    # Import thingyverses private state.
    @_ = thingyverse._

  # Handle create message.
  #
  # Most creates are of the form `id.subkey`.  These are processed with
  # typename and attrs stored in `@_.partials`.  The other two options are
  # `_synced` which causes all partials to be created and `%create` which has
  # a value of an id of a thingy (hopefully in partials) which is then
  # created.
  #
  # @param [String] domain Domain; must match domain of thingyverse.
  # @param [String] key    Key.
  # @param [Object] value  Value.
  # @return [null] null
  create: ( domain, key, value ) ->
    if domain != @_.domain
      @_.on_error( "Received message for unknown domain: #{domain}." )

    if key == '_synced'
      if @_.ready
        @_.flush_partials()
      else
        for k of @_.partials
          @_.partials_to_create[ k ] = true
      @_.on_sync()
    else if key == '%create'
      if @_.ready
        id = value
        info = @_.partials[ id ]
        if ! info?
          @_.on_error( "Missing everything for thingy: #{id}" )
        else
          if @_.ready
            @_.make_thingy( info.typename, id, info.attrs, false )
          else
            @_.partials_to_create[ id ] = true
        delete @_.partials[ id ]
    else if key[0] != '_'
      # Extract id and subkey from key.
      [ id, subkey ] = split_key( key )
      attrs = value
      @_.partials[ id ] ?= {}
      if subkey == '_'
        if ! value.typename?
          @_.on_error( "Cannot understand basekey #{key}.  No typename." )
        if ! value.attrs?
          @_.on_error( "Cannot understand basekey #{key}.  No attrs." )
        if ! @_.per_type[ value.typename ]?
          @_.on_error( "Received basekey #{key} for unknown typename: #{value.typename}." )
        @_.partials[ id ].typename = value.typename
        attrs = value.attrs

      partial_attrs = @_.partials[ id ].attrs ?= {}
      for k, v of attrs
        partial_attrs[ k ] = v
    # else metakey we don't care about.

    null

  # Handle update message.
  #
  # All update messages should be of the form `id.subkey`.  If the thingy
  # exists, it is immediately updated.  Otherwise the message is discarded.
  # This latter behavior can happen if a thingy was removed locally but an
  # update from another client was already in the event queue.
  #
  # @param [String] domain Domain; must match domain of thingyverse.
  # @param [String] key    Key.
  # @param [Object] value  Value.
  # @return [null] null
  update: ( domain, key, value ) ->
    [ id, subkey ] = split_key( key )
    thingy_data = @_.per_thingy[ id ]

    if domain != @_.domain
      @_.on_error( "Received message for unknown domain: #{domain}." )
      return null

    if subkey == '_'
      value = value.attrs

    if ! thingy_data?
      # Check partials.
      if @_.partials[ id ]
        for k, v of value
          @_.partials[ id ][ k ] = v
      # Else discard
      return null

    type_data = @_.per_type[ thingy_data.thingy.typename() ]

    if ! type_data.subkeys[ subkey ]?
      @_.on_error( "Received update for non-existent subkey #{subkey}: #{key}" )
      return null

    thingy_data.delegate.set( thingy_data.thingy, value, false )

    null

  # Handle delete message.
  #
  # See update discussion.
  #
  # @param [String] domain Domain; must match domain of thingyverse.
  # @param [String] key    Key.
  # @return [null] null
  delete: ( domain, key ) ->
    [ id, subkey ] = split_key( key )
    thingy_data = @_.per_thingy[ id ]

    if domain != @_.domain
      @_.on_error( "Received message for unknown domain: #{domain}." )
      return null

    if ! thingy_data?
      # Ensure not in partials.
      delete @_.partials[ id ]
      delete @_.partials_to_create[ id ]

      # Else Discard.
      return null

    thingy_data.delegate.remove( thingy_data.thingy, false )
    delete @_.per_thingy[ id ]

    null

# Begin public.

# A thingy.  See {Heron.Thingyverse#create} for creation.
#
# See {Heron.Thingyverse} for details on thingies.
#
# This class implements a thingy.  You should create them only with
# {Heron.Thingyverse#create}.  Creating one directly will not properly
# identify it as a local create and it will not be propegated to other
# clients.  It is included as part of the public API primarilly for
# documentation purposes.
#
# @see Heron.Thingyverse
# @see Heron.Thingyverse#create
class Heron.Thingy
  # Constructor.  DO NOT CALL.  Use {Heron.Thingyverse#create} instead.
  #
  # @param [Heron.Thingyverse] thingyverse Thingyverse this thingy is part of.
  # @param [String]            typename    Name of thingy type.
  # @param [String]            id          ID of thingy.
  # @param [Object]            attrs       Initial attributes.
  # @param [any]               local_data  False for remote creation; true by
  #   default for local creation, but can be anything creator wants.
  # @throw [String] If called directly.
  # @throw [String] If unknown typename.
  # @throw [String] If duplicate id.
  constructor: ( thingyverse, typename, id, attrs, local_data ) ->
    if ! thingyverse._.make_guard
      throw( 'Heron.Thingy: Do not create Heron.Thingy directly.  Use Heron.Thingyverse#create' )
    if ! thingyverse._.per_type[ typename ]?
      throw( "Heron.Thingy: Unknown typename #{typename}" )
    if thingyverse._.per_thingy[ id ]?
      throw( "Heron.Thingy: Thingy #{id} already exists." )

    @_ =
      thingyverse: thingyverse
      typename:    typename
      id:          id
      type_data:   thingyverse._.per_type[ typename ]
      removed:     false
      assert_not_removed: =>
        if @_.removed
          throw( "Heron.Thingy: Trying to do something with removed thingy #{@id()}" )

    @_.delegate = @_.type_data.initializer.call( this, attrs, local_data )

    thingyverse._.per_thingy[ id ] =
      thingy:   this
      delegate: @_.delegate

  # ID.
  # @return [String] ID.
  id: -> @_.id

  # Name of thingy type.
  # @return [String] Name of thingy type.
  typename: -> @_.typename

  # Thingyverse.
  # @return [Heron.Thingyverse] Thingyverse.
  thingyverse: -> @_.thingyverse

  # Modify attributes.
  #
  # This set operation will propegate to all other clients.  The `local_data`
  # parameter will not propegate; it will be `false` on remote clients.
  #
  # Set works in the following manner:
  #
  # 1. The subkeys that are affected are calculated based on the keys of
  #    attrs.
  # 2. The delegate set method is called.
  # 3. For each subkey, the delegate get method is called with the attributes
  #    of that subkey.  The dicitonary key is then updated appropriately.
  #
  # All of this occurs in a batch.
  #
  # @param [Object] attrs      Attributes to be changed.
  # @param [any]    local_data What to pass to delegates set (See
  #   {Heron.ThingyDelegate#set}) as `local_data` parameter.
  # @return [Heron.Thingy] this
  # @throw [String] If called on a removed thingy.
  set: ( attrs, local_data = true ) ->
    @_.assert_not_removed()

    # Calculate which subkeys need to be updated.
    subkeys = {}
    for attr of attrs
      subkeys[ @_.type_data.attrs[ attr ] ] = true

    # Have delegate do its work.
    @_.delegate.set( this, attrs, local_data )

    # Propagate changes.
    @_.thingyverse.batch =>
      for subkey of subkeys
        @_.thingyverse._.send_update_subkey( this, subkey )

    this

  # Get attributes.
  #
  # This is a purely local operation.  No dictionary modifications occur.
  #
  # @throw [String] if called on a removed thingy.
  # @param [Array<String>] attr_keys... Attributes to get.
  # @return [Object] Object with keys and values for every key in
  #   `attr_keys...`.  May contain additional keys.  Should not be modified.
  # @see #gets
  # @see #geta
  # @throw [String] If called on a removed thingy.
  get: ( attr_keys... ) ->
    @_.assert_not_removed()

    @_.delegate.get( this, attr_keys... )

  # Get a single attribute.
  #
  # Equivalent to: `thingy.get([attr_key])[attr_key]`
  #
  # @param [String] attr_key Attribute to get.
  # @return [Object] value of attribute.
  # @see #gets
  # @see #geta
  # @throw [String] If called on a removed thingy.
  gets: ( attr_key ) ->
    @get( attr_key )[ attr_key ]

  # Get attribtues as array.
  #
  # @param [Array<String>] attr_keys... Attributes to fetch.
  # @return [Array<Object>] Values of `attr_keys`.
  # @see #gets
  # @see #geta
  # @throw [String] If called on a removed thingy.
  geta: ( attr_keys... ) ->
    values = @get( attr_keys... )
    values[k] for k in attr_keys

  # Remove thingy.
  #
  # Calls remove function of delegate and propegates to all other clients
  # (except for `local_data` which will be false on remote clients).
  #
  # This thingy should not be used after removal.
  #
  # @param [any] local_data What to pass to delegates remove (See
  #   {Heron.ThingyDelegate#remove}) as `local_data` parameter.
  # @throw [String] If called on a removed thingy.
  # @return [null] null
  remove: ( local_data = true ) ->
    @_.assert_not_removed()

    # Have delegate do its work.
    @_.delegate.remove( this, local_data )

    # Remote subkeys.
    prefix = id
    @_.thingyverse.batch =>
      for subkey of type_data.subkeys
        key = subkey_key( id, subkey )
        @_.thingyverse._.dictionary.delete( domain, key )

    @_.removed = true

    delete @_.thingyverse._.per_thingy[ id ]

    null

# This class is only for documentation purposes and cannot be used.
#
# When constructing a thingy delegate in an initializer, it should provide
# the same methods as documented below.
#
# @method #set( attrs, local_data )
#   Set attributes given in `attrs`.
#   @param [Object] attrs      Attributes to set.
#   @param [any]    local_data false for remote operations; true by default
#     for local operations, but could be anything setter wants.
#   @return [any] Ignored.
#
# @method #get( attr_keys... )
#   Return an object with a member for each key in `attr_keys...` with value
#   of that attribute.  Allowed to include additional keys.  Return value will
#   be treated as immutable.
#   @param [Array<String>] attr_keys... Keys to return.
#   @return [Object] Object with values of each key in `attr_keys`.
#
# @method #remove( local_data )
#   Do anything necessary before thingy removal.
#   @param [any] local_data false for remote operation; true by default for
#     local operations, but could be anything remover wants.
#   @return [any] Ignored.
class Heron.ThingyDelegate

# Heron.Thingy, through {Heron.Thingyverse}, provides some basic object like
# semantics on top of {Heron.Dictionary}.  It does *not* provide true object
# oriented semantics.  The resulting "objects" are called Thingies to
# distinguish them from javascript Object.  Thingies are a collection of
# attributes, a collection of code that can respond to changes in those
# attributes, and, optionally, some methods.  The entire configuration of a
# thingy needs to be represented by its attributes as it is the attribtues
# that persist and are distributed.
#
# Thingies are collected into thingyverses. A thingyverse is connected to a
# specifiction {Heron.Dictionary} object and domain.  It contains a collection
# of thingy types, creates, updates, and removes thingies across all clients
# involved in the domain.
#
# An important facet of thingies is that operations (create, update, remove)
# can be either local or remote.  A local operation is  generated by the
# client, for example, at user request.  A remote operation is generated by
# another client and communicated to this client from the server.  There is
# code in common to both cases (e.g., updating an attribute) but also
# distinct code (e.g., a local update needs to be sent to the server, but a
# remote update should not.).  To handle this, Heron.Thingy uses delegates.
#
# A thingy is an object with certain methods and semantics.  Whenever, a
# thingy is created, a delegate is also created.  The delegate defines the
# common code for updates, access, and removal --- the code that Heron.Thingy
# must be aware of.  The thingy itself contains some Heron.Thingy generated
# methods (`set`, `get`, `remove`, `id`, `typename`, `thingyverse`) which may
# in turn call delegate methods (set, get, remove).  A Thingy may also have
# additional members or methods as definied by the initializer.  Heron.Thingy
# has no awareness of these additional members/methods.
#
# Every thingy maps to one or more keys in a {Heron.Dictionary}. As
# {Heron.Dictionary} is a persistent/distributed key-value store, Heron.Thingy
# becomes a persistent/distributed object system.  At its most basic, a thingy
# is a single dictionary key containing the name of the thingy type and any
# attributes.  A more complicated thingy may spread its attributes over
# multiple keys. For example, a thingy may contain a great deal of data, but
# only a small amount which changes regularly.  By storing this regularly
# changing data in separate key, the amount of client-server traffic can be
# dramatically reduced.  All attributes are transferred at creation but
# thereafter, only a subset are communicated for each update.  Conversely,
# by storing multiple attributes in a single key, a thingy can reduce the
# number of client-server messages that are sent as well as the number of
# keys the server needs to track.
#
# As a rule of thumb, attributes that (usually) change together should be
# stored in the same key.  Attributes that frequently change should be in
# different keys than attribtues that do not.  Attributes that are set at
# creation at then do not change should be base attributes and
# attributes that do change should be stored in subkeys.  If a thingy has a
# small amount of data, it should all be stored as base attributes, even if
# frequently changing.
#
# Each thingy belongs to a thingy type.  Thingy types must be defined by
# client side code before any messags are received (typically before
# {Heron.Dictionary} is initialized).  A thingy type is a name (known as the
# typename), a set of base attribtues, a map of subkeys to attributes (each
# subkey has a name), and a function known as the initializer which is both
# responsible for any thingy creation semantics (e.g., creating a UI element)
# as well as creating a delegate for the thingy.
#
# Each thingy has a unique identifier (known as its id).  This identifier can
# usually be ignored by the developer -- each thingy is also a distinct
# object, and will usually be referenced as an object by the developer.  The
# identifier can be useful for debugging: the {Heron.Dictionary} keys are
# based on it.  The base key for a thingy has a key of `id._`.  Each
# subkey is of the form `id.subkey` where subkey is the name of the subkey.
# For example, a Thingy with id `123456` and subkey `foo` will have
# {Heron.Dictionary} keys `123456._` and `123456.foo`.  The base key value
# will be an object with two values: `typename` which is a string naming the
# thingy type and `attrs` which is an object containg the base attributes.
# The subkey values will be objects containing the attributes for that subkey.
#
# It is sometimes important for the initializer or delegate to be able to
# distinguish between local and remote operations.  To faciliate this, a
# `local_data` parameter is provided.  By default this is true if the
# operation is local and false if remote.  However, local operations can
# specify their own values for local_data.
#
# Every thingy is based on the {Heron.Thingy} class.  See {Heron.Thingy} for
# details on available methods, e.g., {Heron.Thingy#set}.
#
# Every delegate must be an object as documented in {Heron.ThingyDelegate}.
#
# Every initializer should be a function which takes two arguments -- `attrs`
# and `local_data` -- and returns a delegate.  The `this` of the initializer
# will be set to the thingy object.
#
# As convenience and for future compatibility, {Heron.Thingyverse} defines
# {#batch}, {#begin}, and {#finish}, to provide batch semantics.  At present,
# these are equivalent to {Heron.Dictionary#batch}, {Heron.Dictionary#begin},
# {Heron.Dictionary#finish}, respectively.
class Heron.Thingyverse
  # Construct a Thingyverse.
  #
  # A Thingyverse is a set of thingy types and thingy instances that are
  # connected to a specific {Heron.Dictionary} and domain.
  #
  # After construction, define thingies with {#define} and then connect to a
  # {Heron.Dictionary} via {#connect}.
  #
  # @param [Object] config Configuration.
  # @option config [Function] on_error Error function to call with message
  #   on receiver errors.  Defaults to throw exception.  It may be useful to
  #   change this, to prevent a single malformed dictionary entry from
  #   disrupting an entire batch.
  # @option config [Boolean] ready If false, thingy attributes will be
  #   tracked, but no thingies will be created.  This behavior is useful for
  #   preloading thingies before the context they need is available.  See
  #   {#ready}.  Default: true.
  constructor: ( config = {} ) ->
    # Set up private data
    @_ =
      # Configuration parameters.
      dictionary: null
      domain:     null
      on_sync:    ->
      on_error:   config.on_error ? ( s ) -> throw s
      ready:      config.ready    ? true

      # Map of id to thingy:, delegate:
      per_thingy: {}

      # Map of typename to:
      #
      # - initializer: Function of thingy, attrmap; should return delegate.
      # - attrs:       Map of attr to subkey name with empty meaning base key.
      # - subkeys:     Map of subkey to array of attrs in that subkey.  Empty
      #                string is mapped to base attrs.
      per_type: {}

      # New thingies are received as a series of creates, one for each subkey
      # including base.  The thingy is only created when a create for %create
      # or _synced arrives.  As subkeys arrive, the typename and attrs are
      # stored here.
      #
      # Map of id to typename and attrs.
      partials: {}

      # When thingyverse is not ready, this acts as a set of which partials
      # are ready to be created.  When thingyverse is ready, this is not
      # used.
      partials_to_create: {}

      # Private methods.  See above for documentation.
      send_update_subkey: ( thingy, subkey ) =>
        send_update_subkey.call( this, thingy, subkey )
      send_create: ( thingy ) =>
        send_create.call( this, thingy )
      make_thingy: ( typename, id, domain, attrs, local_data ) =>
        make_thingy.call( this, typename, id, domain, attrs, local_data )
      flush_partials: =>
        flush_partials.call( this )

  # Dictionary.  Null if not connected.
  # @return [Heron.Dictionary] Dictionary used.
  dictionary: -> @_.dictionary

  # Domain.  Null if not connected.
  # @return [Stirng] Domain used.
  domain: -> @_.domain

  # Connect to a dictionary.
  #
  # This should be called after all defines but before any creates.
  #
  # @param [Heron.Dictionary] dictionary Dictionary to connect to.
  # @param [String]           domain     Domain of dictionary to use.
  # @param [Function]         on_sync    Function to call once in sync.
  #   Default: nop
  # @return [Heron.Thingy] this
  # @throw [String] if called a second time.
  connect: ( dictionary, domain, on_sync = -> ) ->
    if @_.dictionary?
      throw "Already connected to a dictionary."
    @_.dictionary = dictionary
    @_.domain     = domain
    @_.on_sync    = on_sync

    # Subscribe to domain.
    receiver = new Receiver( this )
    dictionary.subscribe( @_.domain, receiver )

  # Define a new Thingy Type.
  #
  # Note that the attribute name space is flat.  Thus attribute names need to
  # be unique within a Thingy type.  You can not have two attributes name
  # 'foo' even if they are in different subkeys.
  #
  # The initializer is a function that is given the attrs and local_data
  # parameters from {#create} and has `this` set to the thingy object.  See
  # {Heron.Thingyverse} for more details.
  #
  # It is important that Thingy Types are defined before any messages
  # arrive from {Heron.Dictionary} and that they are consistent with any
  # thingy data stored on the server or other clients.  That is, call all
  # defines before subscribing {Heron.Dictionary}.  Thingy can detect
  # additional or deleted subkeys, but it is up to the delegate to otherwise
  # make sense of definition changes across runs.
  #
  # The return value of the returned function should be treated as undefined.
  # In the future, it may be an object that can be used as a constructor.
  #
  # @todo Have return of (return of) {Heron.Thingyverse#define} be a
  #   constructor.
  #
  # @param [String] typename String naming the type.  This must be unique
  #   across all calls to define for this thingyverse.  It should also be
  #   consistent with any current thingies stored on the server.
  # @param [Array<String>] baseattrs The names of the attributes to store in
  #   the base key.  It can be empty, but is not optional.  Note that there
  #   is no specification of defaults.  Providing default value semantics is
  #   up to the initializer.
  # @param [Object] subkeys Object mapping subkey names to array of
  #   attributes to store in that subkey.
  # @param [Function] initializer Initializer function.  Passed attributes and
  #   local data.
  # @return [Heron.Thingyverse] this
  # @throw [String] If typename is already defined.
  # @throw [String] If duplicate attributes.
  define: ( typename, baseattrs, subkeys, initializer ) ->
    if @_.per_type[ typename ]?
      throw( "Heron.Thingy: #{typename} already defined." )
    else
      type_data =
        typename:    typename
        initializer: initializer
        attrs:       {}
        subkeys:     {}

      type_data.subkeys[ '_' ] = baseattrs
      for attr in baseattrs
        type_data.attrs[attr] = '_'
      for subkey, attrs of subkeys
        type_data.subkeys[ subkey ] = attrs
        for attr in attrs
          if type_data.attrs[ attr ]?
            throw( "Heron.Thingy: Duplicatee attr for #{typename}: #{attr}" )
          type_data.attrs[ attr ] = subkey

      @_.per_type[ typename ] = type_data

      this

  # Create a new thingy.
  #
  # 1. A unqiue identifier is created.
  # 2. A {Heron.Thingy} is instantiated.  It performs step 3.
  # 3. The initializer is called with `this` set to the thingy object.  The
  #    result is set as the delegate.
  # 4. For the base key and every subkey, thingy.get is called with the
  #    appropriate attribute keys and the keys are created in the dictionary.
  # 5. An ephemeral key `%create` is created in the dictionary indicating
  #    that all subkeys have been created and it is time for remote clients
  #    to construct the thingy.
  #
  # All of the above occurs in a batch.
  #
  # @param [String] typename   Name of a Thingy type as definede by {#define}.
  # @param [Object] attrs      Initial attributes.
  # @param [Object] local_data Local data.
  # @return [thingy] Newly created thingy.
  # @throw [String] if not connected.
  # @throw [String] if not ready (See {#ready}).
  create: ( typename, attrs = {}, local_data = true ) ->
    if ! @_.ready
      throw "Call #ready first."
    if ! @_.dictionary
      throw "Call #connect first."
    id = Heron.Util.generate_id()
    while @_.per_thingy[ id ]?
      id = Heron.Util.generate_id()

    thingy = @_.make_thingy( typename, id, attrs, local_data )

    if thingy?
      @_.send_create( thingy )

    thingy

  # Create all pending thingies and allow future creation.
  #
  # Indicates that the caller is ready for thingies to be created.  Calling
  # this is usually unnecessary, as, by default, a thingyverse is created
  # ready.  However, if ready was set to false at construction, you should
  # call this when you are ready for thingies to be created.
  #
  # @throw [String] if already ready.
  # @return [Heron.Thingyverse] this
  ready: ->
    if @_.ready
      throw "Already ready."

    for id of @_.partials_to_create
      info = @_.partials[ id ]
      if ! info?
        throw "Insanity error: Partial to create but no info!"
      @_.make_thingy( info.typename, id, info.attrs, false )
      delete @_.partials[ id ]
      delete @_.partials_to_create[ id ]

    this

  # See {Heron.Dictionary#batch}.
  batch: ( f ) ->
    @_.dictionary.batch( f )

  # See {Heron.Dictionary#begin}.
  begin: ->
    @_.dictionary.begin()

  # See {Heron.Dictionary#finish}.
  finish: ->
    @_.dictionary.end()

  # Loop through every thingy.
  #
  # @param [Function] f Called with each thingy in turn.
  # @return [Array<Object>] All returns of f.
  each_thingy: ( f ) ->
    for id, data of @_.per_thingy
      f( data.thingy )

  # Fetch a thingy by id.
  #
  # @param [String] id Id of thingy.
  # @return [thingy] Thingy with given id.
  thingy_by_id: ( id ) ->
    @_.per_thingy[ id ]?.thingy
