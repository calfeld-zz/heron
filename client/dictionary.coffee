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

Heron = @Heron ?= {}

# This is the client-side interface of Dictionary, a distributed and
# persistent key value store.
#
# Dictionary provides a combination of a shared hash and chat room semantics.
# At heart, it provides a series of maps, called *domains*, of keys to values
# with a basic CRUD (create, update, delete) interface.  Clients can
# *subscribe* to a domain and receive messages for on any operation.  For a
# group of clients, all subscribed to the same domain, this effectively
# provides a map that is kept synchronized between all clients.
#
# Each domain is independent of the others.  There are no guarantees of order
# for operations between domains.  Within a single domain, operations from any
# specific client will not be reordered.  Furthermore, operations in a
# *batch*, will not be interleaved with operations from other clients.
#
# Basic collision detection is provided.  As an example, consider clients `A`
# and `B` and a existant key `k` with value `v0`.  `A` updates `k` to value
# `v1`.  Before the notice of this operation reaches `B`, it updates `k` to
# value `v2`.  Without any collision detection, from the viewpoint of `A`
# events are: update(`k`, `v1`), update(`k`, `v2`), and the viewpoint from
# `B`: update(`k`, `v2`), update(`k`, `v1`), leaving `A` and `B` in
# disagreement as to the value of `k`.  To avoid this, the collision is
# detected by the server.  Assuming it sees the update from `A` first, it will
# then ignore the "invalid" update from `B`.  Then `A` will see: update(`k`,
# `v1`) and `B` will see: update(`k`, `v2`), update(`k`, v1), leaving them in
# sync.  Note that B does have a different event stream though; an aspect
# client code must accomodate.  Similar behavior applies to create collisions
# (create an already existant key) and delete collisions (deleting a
# non-existant) key.
#
# There is no requirement that a client subscribe to a domain before altering
# it.  Write operations and change notifications are independent.
#
# On subscription, create operations for every key in the domain will be sent.
# A special key, `_clients` with a value of an array of all client ids will
# also be created.  Finally, a special key, `_synced` with a value of `true`
# will be created.  It is guaranteed it will be created last, allowing the
# client to know when it has received all keys.
#
# As clients subscribe and unsubscribe (via disconnect), special `_subscribe`
# and `_unsubscribe` keys will be created with the values of the client id
# subscring or unsubscribing.
#
# An additional feature is *ephemeral* keys.  Ephemeral keys are keys that
# begin with `%` and are treated differently:
#
# - Often managed with only create messages, i.e., no updates or deletes.
# - Not stored on server so not provide on subscribe.
# - Not checked for collisions.
#
# Ephemeral keys are intended to be used for message buses.
#
# Dictionary uses {Heron.Comet} to receive event notifcations.  {#receive}
# should be used as the receiver for {Heron.Comet} and the client should set
# this connection up.  In addition, any subscription requires the
# {Heron.Comet} client id.
#
# To receive notifcations, provide a receiver object on subscription with the
# methods:
#
# - `create( domain, key, value )`
# - `update( domain, key, value )`
# - `delete( domain, key )`
#
# Operations may be combined into a batch.  All operations in a batch are
# sent to the server as a single message.  Batches are more efficient and are
# guaranteed (within a domain) not be interleaved with messages from other
# clients.
#
# Keys can be any string, but the first character should be in `A-Za-z0-9./`
# as other characters have special meaning or are researched for future use.
# Keys beginning with `_` are used to communicate aspects of Dictionary, e.g.,
# `_synced`.  Such server keys should be treated as ephemeral.
# Keys beginning with `%` are client ephemerals.
#
# @author Christopher Alfeld (calfeld@calfeld.net)
# @copyright 2010-2012 Christopher Alfeld
class Heron.Dictionary
  # Constructor.
  #
  # @param [object] config Configuration.
  # @option config [string] client_id Client id.  Must be the same as the
  #   the Comet client id.
  #   Required if subscriptions ({#subscribe}) are used.
  # @option config [boolean] debug If true, additional information will be
  #   displayed in console.
  #   Default: false.
  # @option config [path] path Path to dictionary controller.
  #   Default: '/dictionary'
  constructor: ( config = {} ) ->
    @_ =
      client_id:  config.client_id
      debug:      config.debug      ? false
      path:       config.path       ? '/dictionary'
      batch:      0
      messages:   []
      versions:   {}
      receivers:  {}

    @_.issue_message = ( message ) =>
      throw 'Missing domain.'  if ! message.domain?
      throw 'Missing command.' if ! message.command?

      message.value = JSON.stringify( message.value )

      @_.pdebug( 'OUT', message )

      if @_.batch == 0
        @_.send_to_server( 'messages',
          messages: JSON.stringify([ message ])
        )
      else
        @_.messages.push( message )
      null

    @_.send_to_server = ( command, parameters = null ) =>
      parameters.client_id = @_.client_id if @_.client_id?
      jQuery.post(
        "#{@_.path}/#{command}",
        parameters
      )
      null

    @_.is_ephemeral = ( key ) -> key[0] == '%'

    @_.pdebug = ( args... ) ->
    if @_.debug
      @_.pdebug = ( args... ) -> console.debug( 'Heron.Dictionary', args... )

    @_.pdebug( 'initialized' )

  # Receiver for {Heron.Comet}.
  #
  # @param [string] JSON JSON text of messages.
  # @return [Heron.Dictionary] this.
  receive: ( json ) ->
    messages = jQuery.parseJSON( json )
    @_.pdebug( 'IN begin' )
    active_receivers = {}
    for message in messages
      ephemeral = @_.is_ephemeral( message.key )
      receivers = @_.receivers[ message.domain ]
      for r in receivers
        if ! active_receivers[ r ]?
          active_receivers[ r ] = true
          r.begin?()
      if ! receivers?
        next
      switch message.command
        when 'create'
          @_.pdebug( 'IN create', message.domain, message.key, message.value )
          for r in receivers
            r.create?( message.domain, message.key, jQuery.parseJSON( message.value ) )
          if ! ephemeral
            @_.versions[message.domain] ?= {}
            @_.versions[message.domain][message.key] = message.version
        when 'update'
          @_.pdebug( 'IN update', message.domain, message.key, message.value )
          for r in receivers
            r.update?( message.domain, message.key, jQuery.parseJSON( message.value ) )
          if ! ephemeral
            @_.versions[message.domain] ?= {}
            @_.versions[message.domain][message.key] = message.version
        when 'delete'
          @_.pdebug( 'IN delete', message.domain, message.key )
          for r in receivers
            r.delete?( message.domain, message.key )
          if ! ephemeral
            delete @_.versions[message.domain][message.key]
        else
          error( "Unknown command: #{message.command}" )
    for r of active_receivers
      r.finish?()
    @_.pdebug( 'IN finish' )
    this

  # This is exactly:
  #   begin()
  #   f()
  #   finish()
  #
  # See {#begin}.
  #
  # @param [function] f Function to call.
  # @return [Heron.Dictionary] this
  batch: ( f ) ->
    @begin()
    f()
    @finish()
    this

  # Begin a batch.  Multiple begins can be called.  The batch is executed
  # when an identical number of finishes have been called.
  #
  # Batches are more efficient than individual operations and, within a
  # domain, will not be interleaved with operations from other clients.
  #
  # @return [Heron.Dictionary] this
  begin: ->
    @_.pdebug( 'OUT begin batch' )
    @_.batch += 1
    this

  # Finish a batch.  If the same number of finishes and begins have now been
  # called, all messages are sent to the server.
  #
  # @return [Heron.Dictionary] this
  finish: ->
    @_.pdebug( 'OUT finish batch' )
    if @_.batch == 0
      error( 'Finishing at batch level 0.' )
    else
      @_.batch -= 1
      if @_.batch == 0
        @_.pdebug( 'OUT execute batch' )
        @_.send_to_server( 'messages',
          messages: JSON.stringify( @_.messages )
        )
        @_.messages = []
    this

  # Subscribe to a domain.
  #
  # Requires that `client_id` was configured on construction.
  #
  # @param [String] domain Domain to subscribe to.
  # @return [Heron.Dictionary] this
  subscribe: ( domain, receiver ) ->
    throw 'Missing client_id.' if ! @_.client_id?
    if ! @_.receivers[ domain ]
      @_.pdebug( 'SUBSCRIBE', domain )
      @_.send_to_server( 'subscribe', domain: domain )
      @_.receivers[ domain ] = []
    @_.receivers[ domain ].push( receiver )
    this

  # Update.
  #
  # @param [string] domain Domain to update.
  # @param [string] key    Key to update.
  # @param [any]    value  New value.
  # @return [Heron.Dictionary] this
  update: ( domain, key, value ) ->
    message =
      command: 'update'
      domain:  domain
      key:     key
      value:   value
    if ! @_.is_ephemeral( key )
      message.previous_version = @_.versions[domain][key]
      message.version          = Heron.Util.generate_id()
      @_.versions[domain][key] = message.version
    @_.issue_message( message )
    this

  # Create.
  #
  # @param [string] domain Domain to create in.
  # @param [string] key    Key to create.
  # @param [any]    value  Initial value.
  # @return [Heron.Dictionary] this
  create: ( domain, key, value ) ->
    message =
      command: 'create'
      domain:  domain
      key:     key
      value:   value
    if ! @_.is_ephemeral( key )
      message.version = Heron.Util.generate_id()
      @_.versions[domain] ?= {}
      @_.versions[domain][key] = message.version
    @_.issue_message( message )
    this

  # Delete.
  #
  # @param [string] domain Domain to delete from.
  # @param [key]    key    Key to delete.
  # @return [Heron.Dictionary] this
  delete: ( domain, key ) ->
    message =
      command: 'delete'
      domain:  domain
      key:     key
    @_.issue_message( message )
    this

