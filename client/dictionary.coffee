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

# Private

# All of these are private methods of Heron.Dictionary and must be called
# as X.call( this, ... )

command = ( cmd, domain, key, value ) ->
  @_.pdebug( "OUT", cmd, domain, key, value )

  message =
    command: cmd
    domain: domain
    key: key

  if value
    message.value = JSON.stringify( value )

  if @_.batch == 0
    send_messages.call( this, [ message ] )
  else
    @_.messages.push( message )

  null

send_to_dictionary = ( command, parameters ) ->
  parameters.client_id = @_.client_id
  jQuery.post(
    "#{@_.path}/#{command}",
    parameters
  )
  null

send_messages = ( messages ) ->
  send_to_dictionary.call(
    this,
    "messages",
    messages: JSON.stringify( messages )
  )
  null

dictionary_connect = ->
  send_to_dictionary.call(
    this,
    'connect',
    session_id: @_.session_id
  )
  jQuery(document).trigger( "Heron.Dictionary:connected" );
  null

# This is the client-side interface of Dictionary, a distributed and
# persistent key value store.
#
# The dictionary is a map of `[domain,key]` to values.  Domains are set by the
# server.  A session is a set of domains.  When a client connects to the
# Dictionary system is specifies which session to the connect to.  This
# session id in turn determines the Dictionary domains.
#
# Operations are create, delete, and update.  All operations are sent to the
# server which then distributes them to all other connected clients for
# that domain.  The server also maintains the current value.
#
# As a special case, on connecting, the server sends create messages for all
# current keys to the client.
#
# {#receive} is meant to be called as the receiver from the {Heron.Comet}
# class.  This connection needs to be set up by the caller.
#
# Dictionary also takes a receiver object which should define:
#
# - `create( domain, key, value )`
# - `update( domain, key, value )`
# - `delete( domain, key )`
#
# Dictionary allows operations to be combined into a batch.  All operations
# in a batch are sent to the server as a single message which has both
# efficiency and single operation semantics on the server.
#
# There is a special, meta-domain, _, which is used to communicate dictionary
# information.  At present, there is a single key, `synced`, which will be
# created with value true as the last event in the initial on-connect
# batch.
#
# The following event is fired with the {Heron.Dictionary} instance as memo.
#
# - `Heron.Dictionary:connected` Fired on connection.
#
# @author Christopher Alfeld (calfeld@calfeld.net)
# @copyright 2010-2012 Christopher Alfeld
class Heron.Dictionary
  # Constructor.
  #
  # @param [object] config Configuration.
  # @option config [object] receiver Receiver of messages.  See
  #   {Heron.Dictionary}.
  #   Required.
  # @option config [string] session_id Session to join.
  #   Required.
  # @option config [string] client_id Client id.  Must be the same as the
  #   the Comet client id.
  # @option config [boolean] debug If true, additional information will be
  #   displayed in console.
  #   Default: false.
  # @option config [path] path Path to dictionary controller.
  #   Default: "/dictionary"
  constructor: ( config = {} ) ->
    @_ =
      receiver:   config.receiver   ? throw "Missing receiver."
      session_id: config.session_id ? throw "Missing session id."
      client_id:  config.client_id  ? throw "Missing client id."
      debug:      config.debug      ? false
      path:       config.path       ? "/dictionary"
      batch:      0
      messages:   []

    @_.pdebug = ( args... ) ->
    if @_.debug
      @_.pdebug = ( args... ) -> console.debug( "Heron.Dictionary", args... )

    jQuery(document).on(
      "Heron.Comet:connected",
      => dictionary_connect.call( this )
    )

    @_.pdebug( "initialized" )

  # Receiver for {Heron.Comet}.
  #
  # @param [string] JSON JSON text of messages.
  # @return [Heron.Dictionary] this.
  receive: ( json ) ->
    messages = jQuery.parseJSON( json )
    @_.pdebug( "IN begin" )
    @_.receiver.begin?()
    for message in messages
      switch message.command
        when "create"
          @_.pdebug( "IN create", message.domain, message.key, message.value )
          @_.receiver.create?( message.domain, message.key, jQuery.parseJSON(message.value) )
        when "update"
          @_.pdebug( "IN update", message.domain, message.key, message.value )
          @_.receiver.update?( message.domain, message.key, jQuery.parseJSON(message.value) )
        when "delete"
          @_.pdebug( "IN delete", message.domain, message.key, message.value )
          @_.receiver.delete?( message.domain, message.key )
        else
          error( "Unknown command: #{message.command}" )
    @_.receiver.finish?()
    @_.pdebug( "IN finish" )
    this

  # This is exactly:
  #   begin()
  #   f()
  #   finish()
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
  # @return [Heron.Dictionary] this
  begin: ->
    @_.pdebug( "OUT begin batch" )
    @_.batch += 1
    this

  # Finish a batch.  If the same number of finishes and begins have now been
  # called, all messages are sent to the server.
  #
  # @return [Heron.Dictionary] this
  finish: ->
    @_.pdebug( "OUT finish batch" )
    if @_.batch == 0
      error( "Finishing at batch level 0." )
    else
      @_.batch -= 1
      if @_.batch == 0
        @_.pdebug( "OUT execute batch" )
        send_messages.call( this, @_.messages )
        @_.messages = []
    this

  # Update.
  #
  # @param [string] domain Domain to update.
  # @param [string] key Key to update.
  # @param [any] value New value.
  # @return [Heron.Dictionary] this
  update: ( domain, key, value ) ->
    command.call( this, "update", domain, key, value )
    this

  # Create.
  #
  # @param [string] domain Domain to create in.
  # @param [string] key Key to create.
  # @param [any] value Initial value.
  # @return [Heron.Dictionary] this
  create: ( domain, key, value ) ->
    command.call( this, "create", domain, key, value )
    this

  # Delete.
  #
  # @param [string] domain Domain to delete from.
  # @param [key] key Key to delete.
  # @return [Heron.Dictionary] this
  delete: ( domain, key ) ->
    command.call( this, "delete", domain, key )
    this

