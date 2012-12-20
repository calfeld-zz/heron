#!/usr/bin/env ruby1.9

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

# Underlying server-side support for Heron.Dictionary.
#
# This file defines Heron::Dictionary, a class to do the server side state
# management for Heron.Dictionary.  It should be used in conjunction with a
# controller, e.g., Heron::SinatraDictionary, and the client side library,
# Heron.Dictionary.
#
# See Heron.Dictionary in the client side documentation for details on
# Dictionary.
#
# Author:: Christopher Alfeld (calfeld@calfeld.net)

require 'rubygems'
require 'sqlite3'
require 'thread'

module Heron
  # Dictionary Related Errors
  class DictionaryError < RuntimeError
  end

  # Implements Heron.Dictionary logic.
  #
  # Must be attached to a webserver via a dictionary controller such as
  # {Heron.SinatraDictionary}.
  #
  # This class will spawn a domain worker thread for any domain that receives
  # operations.  Incoming messages will be demultiplexed and queues to the
  # appropriate workers which will then record them in the database and issue
  # messages to any subscribed clients.
  #
  # Databases are stored in a directory as SQLite3 databases.
  #
  class Dictionary
    # @return [String] Path to directory where database are stored.
    attr_reader :db_path
    # @return [Proc] Proc to call with verbose message.
    attr_accessor :on_verbose
    # @return [Proc] Proc to call with error message.
    attr_accessor :on_error
    # @return [Proc] Proc to call with client_id and domain on subscribe.
    attr_accessor :on_subscribe
    # @return [Proc] Proc to call with message on collision.
    attr_accessor :on_collision

    # Constructor.
    #
    # @param [Hash] args Arguments.
    # @option args [Proc] :on_verbose Proc to call with message on verbose
    #   message.  Defauls to nop.
    # @option args [Proc] :on_error Proc to call with error on error message.
    #   Defaults to writing to stderr.
    # @option args [Proc] :on_subscribe Proc to call with client_id and
    #   domain on subscribe.  Defaults to nop.
    # @option args [Proc] :on_collison Proc to call with message on collision.
    #   Defaults to calling on_verbose with prefix of 'COLLISION '.
    # @option args [String] :db_path Path to directory to hold database files.
    #   Does not need to exist.  Required.
    # @option args [Proc] :send Proc to call with client_id and message when
    #   a message needs to be sent, e.g., Heron::Comet#queue.  Required.
    def initialize( args = {} )
      bad = args.keys.to_set - [
        :on_verbose, :on_connect, :on_subscribe, :on_disconnect, :on_error,
        :on_collision, :db_path, :send
      ].to_set
      raise DictionaryError.new("Invalid argument(s): #{bad.to_a}") if ! bad.empty?

      required = -> s { raise DictionaryError.new( "Required: #{s}" ) }
      @on_verbose    = args[ :on_verbose    ] || -> x {}
      @on_subscribe  = args[ :on_subscribe  ] || -> x, y {}
      @on_error      = args[ :on_error      ] || -> x {STDERR.puts "Dictionary Error: #{x}"}
      @on_collision  = args[ :on_collision  ] || -> x {@on_verbose.("COLLISION: #{s}")}
      @db_path       = args[ :db_path       ] || required.( 'db_path' )
      @send          = args[ :send          ] || required.( 'send'    )

      @domain_workers = Hash.new do |h,k|
        info = DomainInfo.new( k, nil, Queue.new, Set.new )
        info.thread = Thread.new {domain_worker( info )}
        h[k] = info
      end
    end

    # Shutdown Dictionary.
    #
    # This will ask every domain worker to shutdown and then wait for them
    # all to exit.  This ensures that any messages received but not sent
    # before shutdown was called are recorded and distributed.
    def shutdown
      @on_verbose.( 'Shutting down...' )
      @domain_workers.each do |domain, info|
        info.queue << nil
      end
      @domain_workers.each do |domain, info|
        info.thread.join
      end
      @on_verbose.( 'Shut down.' )
    end

    # Handle messages from client.
    #
    # @param [String] client_id Client ID of sender.
    # @param [String] messages Messages in JSON.
    # @return [undefined] undefined
    def messages( client_id, messages )
      by_domain = Hash.new {|h,k| h[k] = []}
      JSON.parse( messages ).each do |message|
        command = message[ 'command' ]
        raise "Missing command." if ! command
        domain = message[ 'domain' ]
        raise "Missing domain." if ! domain
        key = message[ 'key' ]
        raise "Missing key." if ! key

        by_domain[ domain ] << message
      end

      by_domain.each do |domain, messages|
        issue( :messages, domain, client_id, messages )
      end
    end

    # Server-side create operation.
    #
    # @param [String] domain  Domain.
    # @param [String] key     Key.
    # @param [String] value   Value.  Must be string, convert complex objects
    #                         to JSON.
    # @param [String] version Initial version.
    # @return [undefined] undefined
    def create( domain, key, value, version = nil )
      issue( :messages, domain, nil, [{
        'command' => 'create',
        'domain'  => domain,
        'key'     => key,
        'value'   => value,
        'version' => version
      }])
    end

    # Update server-side update operation.
    #
    # This method is of dubious use for non-ephemeral keys as you are
    # unlikely to be aware of the current versions and thus unable to update
    # without collision.
    #
    # @param [String] domain  Domain.
    # @param [String] key     Key.
    # @param [String] value   Value.  Must be string, convert complex objects
    #                         to JSON.
    # @param [String] previous_version Previous version.
    # @param [String] version Initial version.
    # @return [undefined] undefined
    def update( domain, key, value, previous_version = nil, version = nil )
      issue( :messages, domain, nil, [{
        'command'          => 'update',
        'domain'           => domain,
        'key'              => key,
        'value'            => value,
        'previous_version' => previous_version,
        'version'          => version
      }])
    end

    # Delete server-side update operation.
    #
    # @param [String] domain  Domain.
    # @param [String] key     Key.
    # @return [undefined] undefined
    def delete( domain, key )
      issue( :messages, domain, nil, [{
        command: 'delete',
        domain:  domain,
        key:     key
      }])
    end


    # Subscribe a client to a domain.
    #
    # @param [String] client_id Client to subscribe.
    # @param [String] domain    Domain to subscribe to.
    def subscribe( client_id, domain )
      @on_verbose.( "JOIN #{client_id} #{domain}" )
      @on_subscribe.( client_id, domain )

      issue( :subscribe, domain, client_id )
    end

    private

    # Per-domain info.
    DomainInfo = Struct.new(
      :domain, # Domain name.
      :thread, # Worker thread.
      :queue,  # Queue of metamessages for domain worker.
      :clients # Subscribe clients to domain.
    )

    # Send message to dictionary clients.
    #
    # @param [Array<String>] to      Array of client ids.
    # @param [String]        json    Message to send.
    # @yield String No longer valid client id.
    # @return [undefined] undefined
    def send_messages( to, json )
      to.each do |client_id|
        begin
          @send.( client_id, json )
        rescue Heron::CometError => e
          @on_verbose.(
            "Could not send to #{client_id}.  " +
            "Assuming disconnected: #{e.to_s}"
          )
          yield client_id
        end
      end
    end

    # Low level issue a command.
    #
    # This queues a command for a domain worker to handle.  It allows server
    # side low level protocol operations.  For server side key operations, see
    # #create, #update, and #delete.
    #
    # @param [String] command   Command to issue to domain worker.
    # @param [String] domain    Domain to issue command for.
    # @param [String] client_id Client ID to use.  Can be nil to indicate
    #                           server origin.
    # @param [Array<Object>] info Any additional arguments.
    # @return [undefined] undefined
    def issue( command, domain, client_id, *info )
      @domain_workers[ domain ].queue << [ command, client_id, *info ]
    end

    # Main loop for a domain worker.  Does not return until shutdown.
    #
    # @param [DomainInfo] info Domain information.
    # @return [undefined] undefined
    def domain_worker( info )
      # Sanitize domain name before using it as part of filename.
      if info.domain !~ /^\w+$/ || info.domain == '_'
        raise "Invalid domain: #{info.domain}"
      end

      # Long lived thread, so maintain database connections.
      FileUtils.mkdir_p( @db_path )
      db = SQLite3::Database.new(
        File.join( @db_path, info.domain + '.db' )
      )
      db.execute(
        'CREATE TABLE IF NOT EXISTS key_values (
          key, value, version,
          PRIMARY KEY (key)
        )'
      )
      create_q   = db.prepare(
        'INSERT OR REPLACE INTO key_values ' +
        '( key, value, version ) VALUES ( ?, ?, ? )'
      )
      update_q   = db.prepare( 'UPDATE key_values SET value = ?, version = ? WHERE key = ?' )
      delete_q   = db.prepare( 'DELETE FROM key_values WHERE key = ?'          )
      all_keys_q = db.prepare( 'SELECT key, value, version FROM key_values'    )
      query_q    = db.prepare(
        'SELECT value, version FROM key_values ' +
        'WHERE key = ?'
      )

      # Will exit if a nil every shows up on queue.
      while true do
        metamessage = info.queue.pop()
        return if metamessage.nil?

        metacommand = metamessage[0]

        case metacommand
        when :subscribe then
          client_id = metamessage[1]
          info.clients << client_id
          messages =
            all_keys_q.execute().collect do |key, value, version|
              {
                'command' => 'create',
                'domain'  => info.domain,
                'key'     => key,
                'value'   => value,
                'version' => version
              }
            end
          messages << {
            'command' => 'create',
            'domain'  => info.domain,
            'key'     => '_synced',
            'value'   => 'true'.to_json,
            'version' => ''
          }

          send_messages( [client_id], messages.to_json ) do |id|
            info.clients.delete( id )
          end
        when :messages then
          client_id = metamessage[1]
          messages  = metamessage[2]

          if ! messages.is_a?(Array)
            @on_error.( "Invalid messages.  Expected array." )
            next
          end

          messages_to_distribute = []
          messages.each do |message|
            command = message[ 'command' ]
            domain  = message[ 'domain'  ]
            key     = message[ 'key'     ].to_s

            if ! command || ! domain || ! key
              @on_error.( "Invalid message: #{message.inspect}" )
              next
            end

            ephemeral = key[0] == '%'
            value            = message[ 'value'            ] # may be nil
            version          = message[ 'version'          ] # may be nil
            previous_version = message[ 'previous_version' ] # may be nil

            real_value = real_version = nil
            if ! ephemeral
              dbr = query_q.execute( key ).first
              if dbr
                real_value, real_version = dbr
              end
            end

            if ephemeral && command != 'update'
              @on_error.( "Invalid command #{command} for ephemeral key #{key}")
              next
            end

            case command
            when 'create'
              if ! value || ! version
                @on_error.( "Create message missing arguments: #{message.inspect}" )
                next
              end
              if ! real_value.nil?
                @on_collision.( "C #{domain}.#{key} = #{value} [#{version}]" )
                next
              end
              @on_verbose.( "C #{domain}.#{key} [#{version}]" )
              create_q.execute( key, value, version )
            when 'update'
              if ephemeral
                if ! value
                  @on_error.( "Update message missing arguments: #{message.inspect}" )
                  next
                end
                @on_verbose.( "U #{domain}.#{key} = #{value} [ephemeral]" )
              else
                if ! value || ! version || ! previous_version
                  @on_error.( "Update message missing arguments: #{message.inspect}" )
                  next
                end
                if real_version != previous_version
                  @on_collision.( "U #{domain}.#{key} [#{previous_version} vs. #{real_version}]" )
                  next
                end
                @on_verbose.( "U #{domain}.#{key} = #{value} [#{real_version} -> #{version}]" )
                update_q.execute( value, version, key )
              end
            when 'delete'
              if ! real_value
                @on_collision.( "D #{domain}.#{key}" )
                next
              end
              @on_verbose.( "D #{domain}.#{key}" )
              delete_q.execute( key )
            else
              @on_error.( "Unknown command: #{message.inspect}" )
            end

            messages_to_distribute << message
          end
          if ! messages_to_distribute.empty?
            others = info.clients.select {|x| x != client_id}
            send_messages( others, messages_to_distribute.to_json ) do |id|
              info.clients.delete( id )
            end
          end
        else
          # This is a bug, not invalid client input.
          raise "Unknown metacommand: #{metacommand}"
        end
      end
    end
  end
end
