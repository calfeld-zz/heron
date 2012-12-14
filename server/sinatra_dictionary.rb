#!/usr/bin/env ruby1.9

# Copyright 2012 Christopher Alfeld
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

# Examplish Sinatra support for Heron::Dictionary.
#
# This files defines the Heron::SinatraDictionary that can included into a
# Sinatra::Base subclass to define a Heron::Dictionary controller.  For simple
# applications, it should suffice.  For more complex applications, or
# non-Sinatra servers, SinatraDictionary can serve as example of how to
# connect HTTP requests to Dictionary operations.
#
# Author:: Christopher Alfeld (calfeld@calfeld.net)

require 'server/dictionary'
require 'json'

module Heron

# Mixin for Sinatra::Base subclass to add dictionary support.
#
# By default, sets up the dictionary controller at "/dictionary/...".  This
# path can be changed by defining a class constant, DICTIONARY_PREFIX,
# *before* including this mixin.
#
# If the Base subclass defines a {#dictionary_trace} method, it will be called
# with a single string argument with trace information on every operation.  It
# defaults to no operation.
#
# If the Base subclass defines a {#dictionary_error} method, it will be called
# with a single string argument with error messages.  It defaults to
# outputting messages to STDERR.
#
# The base subclass *must* define a {#dictionary_path} method that returns a
# string specifying the path of where to store the dictionary database.
#
# The Heron::Dictionary object can be accessed via the instance method
# {#dictionary}.  A {#send_messages} method is also added to support sending
# messages to client in a dictionary friendly way.  It is not required ---
# you may directly use comet to send messages --- but using it will help
# Dictionary keep its active clients tables up to date.
#
# The {#dictionary_disconnect} method must be called from the Comet
# on_disconnect handler.
#
# Routes created by default (see above):
# - get /dictionary/connect
# - get /dictionary/disconnect
# - get /dictionary/messages
#
# See also Heron::Dictionary
#
module SinatraDictionary
  # Setup routes.
  def self.included(base)
    if ! base.const_defined?(:DICTIONARY_PREFIX)
      base.const_set(:DICTIONARY_PREFIX, "/dictionary")
    end

    prefix = base.const_get(:DICTIONARY_PREFIX)

    base.post prefix + '/connect' do
      client_id  = params[ 'client_id' ]
      session_id = params[ 'session_id' ]

      dictionary_trace( "CONNECT #{client_id} #{session_id}" )

      raise "Missing client_id." if ! client_id
      raise "Missing session_id." if ! session_id

      dictionary.transaction do
        dictionary.connect_client( client_id, session_id )

        messages =
          dictionary.keys_for_client( client_id ).collect do |domain,key,value|
            {
              command: 'create',
              domain:  domain,
              key:     key,
              value:   value
            }
          end
        messages << {
          command: 'create',
          domain:  '_',
          key:     'synced',
          value:   'true'.to_json
        }

        send_messages( [client_id], messages.to_json )
      end
      200
    end

    base.post prefix + '/disconnect' do
      client_id = params[ 'client_id' ]

      dictionary_trace( "DISCONNECT #{client_id}" )

      raise "Missing client_id." if ! client_id
      dictionary.disconnect_client( client_id )
      200
    end

    base.post prefix + '/messages' do
      client_id = params[ 'client_id' ]
      messages  = params[ 'messages' ]

      raise "Missing client_id." if ! client_id
      raise "Missing messages."  if ! messages

      handle_messages_json( client_id, messages )

      others = dictionary.other_clients_in_session_as( client_id )
      send_messages( others, messages )
      200
    end
  end

  private
  def handle_messages_json( domain, messages_json )
    JSON.parse( messages_json ).each do |message|
      command = message[ 'command' ]
      raise "Missing command." if ! command
      domain = message[ 'domain' ]
      raise "Missing domain." if ! domain
      key = message[ 'key' ]
      raise "Missing key." if ! key

      value = message[ 'value' ] # may be nil

      case command
      when 'create'
        raise "Missing value." if ! value
        dictionary_trace( "C #{domain}.#{key} = #{value}" )
        dictionary.create_key( domain, key.to_s, value )
      when 'update'
        raise "Missing value." if ! value
        dictionary_trace( "U #{domain}.#{key} = #{value}" )
        dictionary.update_key( value, domain, key.to_s  )
      when 'delete'
        dictionary_trace( "D #{domain}.#{key}" )
        dictionary.delete_key( domain, key.to_s )
      else
        raise "Invalid command: #{message['command']}"
      end
    end
  end

  public

  # Send message to dictionary clients.
  #
  # @param [Array<String>] to   Array of client ids.
  # @param [String]        json Message to send.
  # @return [undefined] undefined
  def send_messages( to, json )
    bad_clients = []
    to.each do |client_id|
      begin
        comet.queue( client_id, json )
      rescue Heron::CometError => e
        dictionary_error "Could not send to #{client_id}.  " +
          "Perhaps disconnected: #{e.to_s}"
        bad_clients << client_id
      end
    end

    if ! bad_clients.empty?
      dictionary_trace "Cleaning up #{bad_clients.size} bad clients."
      dictionary.transaction do
        bad_clients.each do |client_id|
          dictionary_disconnect( client_id.to_s )
        end
      end
    end
  end

  # Access shared Heron::Dictionary object.
  #
  # @return [Dictionary] Connected {Heron::Dictionary} object.
  def dictionary
    @dictionary ||= ::Heron::Dictionary.new( dictionary_path )
  end

  # Default trace.  Override to output trace information.
  #
  # @param [String] message Message to trace.
  # @return [undefined] undefined
  def dictionary_trace( message )
    # nop
  end

  # Default error.  Override to output error information.
  #
  # @param [String] message Message to emit.
  # @return [undefined] undefined
  def dictionary_error( message )
    STDERR.puts "Heron.Dictionary ERROR: #{message}"
  end

  # This should be called by the on_disconnect {Heron::Comet} handler.
  #
  # @param [String] client_id Comet/Dictionary client_id.
  # @return [undefined] undefined
  def dictionary_disconnect( client_id )
    dictionary.disconnect_client( client_id.to_s )
  end

  # This must be overriden with the path to the database file.
  #
  # @return [String] Path to dictionary SQLite database file.
  def dictionary_path
    raise "Must override dictionary_path."
  end
end

end
