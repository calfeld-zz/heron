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

c_max_reconnect_retry = 1

reconnect = ->
  receive.call( this )
  # This will flush out any already active receive on the server.
  new Ajax.Request(
    @__.path + "/flush"
    method: 'get'
    parameters:
      client_id: @__.client_id
  )
  null

receive = ->
  return null if ! @__.connected

  failure = =>
    @__.connected = false
    $(document).fire( "Heron.Comet:lost", this )

  new Ajax.Request(
    @__.path + "/receive"
    method: 'get'
    parameters:
      client_id: @__.client_id,
    onSuccess: ( transport ) =>
      # This check allows us to deal with reloads and window closes
      # gracefully.
      return if ! @__.connected

      if transport.status != 200
        if @__.reconnect_retry < c_max_reconnect_retry
          verbose( "disconnected; trying to reconnect." )
          ++@__.reconnect_retry
          setTimeout(
            => reconnect.call( this ),
            0
          )
        else
          verbose( "disconnected; retry count exceeded." )
          failure()
      else
        if @__.reconnect_retry > 0
          @__.verbose( "reconnected." )
          @__.reconnect_retry = 0
        if transport.responseText != ""
          @__.verbose( transport.responseText )
          @__.on_message( transport.responseText, this )
        setTimeout(
          => receive.call( this ),
          0
        )
    onFailure: ( e ) ->
      failure( e )
    onException: ( e, text ) =>
      @__.on_exception( e, text, this )
  )
  null

# Client-side Comet support.
#
# This is the client-side code for Heron.Comet.  Instantiate a Heron.Comet
# instance for for each Heron.Comet controller you wish to use, passing in
# a message handler on construction. After instantiating, call {#connect}.
# Any messages from the server will then be passed to the message handler.
#
# There are a number of additional options and hnalders available.  See the
# constructor for details.
#
# The following events are fired, in all cases, memo will be Heron.Comet
# instance.
#
# - `Heron.Comet:connected`    Fired on connection.
# - `Heron.Comet:disconnected` Fired on disconnect.
# - `Heron.Comet:lost`         Fired on connection lost.
#
# @author Christopher Alfeld (calfeld@calfeld.net)
# @copyright 2010-2012 Christopher Alfeld
class Heron.Comet

  # Constructor
  #
  # @param [object] config Configuration.
  # @option config [string]   path          Path to Comet controller.
  #   Default: "/comet"
  # @option config [function] on_message   Function to call when message
  #   received.  Passed message and this.
  # @option config [function] on_exception Function to call if an exception
  #   is thrown while processing the message.  Passed exception, text,
  #   and this.  Defaults to a verbose message.
  # @option config [function] on_verbose   Function to call with verbose
  #   messages and this.  Defaults to discard.
  # @option config [string]   client_id    Client ID.  Defaults to
  #   {Heron.Util.generate_id}
  constructor: ( config ) ->
    @__ =
      path:            config.path         ? "/comet"
      on_message:      config.on_message   ? ->
      on_verbose:      config.on_verbose   ? ->
      on_exception:    config.on_exception ? ( e, text, comet ) =>
        @__.verbose( "Exception: #{text}" )
      client_id:       config.client_id    ? Heron.Util.generate_id()
      connected:       false
      verbose:         ( s ) => @__.on_verbose( "comet: #{s}", this )
      reconnect_retry: 0

    # Watch for unloads to avoid loss being called when the web page is
    # left.
    Event.observe( window, "beforeunload", @disconnect )

    @__.verbose( "initialized" )

  # Client ID reader.
  #
  # @return [string] Client ID.
  client_id: ->
    @__.client_id

  # True iff connected to server.
  #
  # @return [bool] True iff connected to server.
  connected: ->
    @__.connected

  # Connect to server.
  #
  # @return [object] this
  connect: ->
    new Ajax.Request(
      @__.path + "/connect"
      method: 'get'
      parameters:
        client_id: @__.client_id
      onSuccess: =>
        @__.connected = true
        receive.call( this )
        @__.verbose( "connected" )
        $(document).fire( "Heron.Comet:connected", this )
    )
    this

  # Disconnect from server.
  #
  # This is automatically called on page unload.
  #
  # @return [object] this
  disconnect: ->
    if @__.connected
      new Ajax.Request(
        @__.path + "/disconnect"
        method: 'get'
        parameters:
          client_id: @__.client_id
        onSuccess: =>
          @__.connected = false
          $(document).fire( "Heron.Comet:disconnected", this )
      )
    this


