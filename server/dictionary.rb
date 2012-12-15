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
# Author::    Christopher Alfeld (calfeld@calfeld.net)

require 'rubygems'
require 'sqlite3'

module Heron
  # Dictionary Related Errors
  class DictionaryError < RuntimeError
  end

  # Implements Heron.Dictionary logic.
  #
  # Must be attached to a webserver via a dictionary controller such as
  # {Heron.SinatraDictionary}.
  #
  class Dictionary
    # @return [String] Path to SQLite database.
    attr_reader :db_path
    # @return [Proc] Proc to call with verbose message.
    attr_accessor :on_verbose
    # @return [Proc] Proc to call with error message.
    attr_accessor :on_error
    # @return [Proc] Proc to call with client_id and session ID on connect.
    attr_accessor :on_connect
    # @return [Proc] Proc to call with client_id on connect.
    attr_accessor :on_disconnect

    # Constructor.
    #
    # @param [Hash] args Arguments.
    # @option args [Proc] :on_connect Proc to call with client_id and
    #   session_id on connect.  Defaults to nop.
    # @option args [Proc] :on_disconnect Proc to call with client_id on
    #   disconnect.  Defaults to nop.
    # @option args [Proc] :on_verbose Proc to call with message on verbose
    #   message.  Defauls to nop.
    # @option args [Proc] :on_error Proc to call with error on error message.
    #   Defaults to writing to stderr.
    # @option args [String] :db_path Path to database file.  If file
    #   does not exist, new database will be initialized.  Required.
    # @option args [Proc] :comet Proc to return Heron::Comet instance to use.
    #   Required.
    def initialize( args = {} )
      bad = args.keys.to_set - [
        :on_verbose, :on_error, :db_path, :comet
      ].to_set
      raise DictionaryError.new("Invalid argument(s): #{bad.to_a}") if ! bad.empty?

      required = -> s { raise DictionaryError.new( "Required: #{s}" ) }
      @on_verbose    = args[ :on_verbose ]    || -> x {}
      @on_connect    = args[ :on_connect ]    || -> x, y {}
      @on_disconnect = args[ :on_disconnect ] || -> x {}
      @on_error      = args[ :on_error ]      || -> x {STDERR.puts "Dictionary Error: #{x}"}
      @db_path       = args[ :db_path ]       || required.( 'db_path' )
      @comet         = args[ :comet ]         || required.( 'comet'   )
    end

    # Send message to dictionary clients.
    #
    # @param [Array<String>] to   Array of client ids.
    # @param [String]        json Message to send.
    # @param [HeronDatabase] db   Database conenction to use; default to new.
    # @return [undefined] undefined
    def send_messages( to, json, db = database )
      bad_clients = []
      to.each do |client_id|
        begin
          comet.queue( client_id, json )
        rescue Heron::CometError => e
          error "Could not send to #{client_id}.  " +
            "Perhaps disconnected: #{e.to_s}"
          bad_clients << client_id
        end
      end

      if ! bad_clients.empty?
        verbose "Cleaning up #{bad_clients.size} bad clients."
        db.transaction do
          bad_clients.each do |client_id|
            disconnect( client_id.to_s, db )
          end
        end
      end
    end

    # Handle messages from client.
    #
    # @param [String] client_id Client ID of sender.
    # @param [String] messages Messages in JSON.
    # @return [undefined] undefined
    def messages( client_id, messages )
      handle_messages_json( client_id, messages )

      db = database
      others = db.other_clients_in_session_as( client_id )
      send_messages( others, messages, db )
    end

    # Connect client to session.
    #
    # @param [String] client_id ID of connecting client.
    # @param [String] session_id ID of session to connect to.
    # @return [undefined] undefined
    def connect( client_id, session_id )
      verbose( "CONNECT #{client_id} #{session_id}" )
      @on_connect.( client_id, session_id )

      db = database
      db.transaction do
        db.connect_client( client_id, session_id )

        messages =
          db.keys_for_client( client_id ).collect do |domain,key,value|
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

        send_messages( [client_id], messages.to_json, db )
      end
    end

    # Disconnect client.
    #
    # This should be called by the on_disconnect {Heron::Comet} handler.
    #
    # @param [String] client_id ID of disconnecting client.
    # @param [DictionaryDB] db Database connection to use; default to new.
    # @return [undefined] undefined
    def disconnect( client_id, db = database )
      verbose( "DISCONNECT #{client_id}" )
      @on_disconnect.( client_id )

      database.disconnect_client( client_id.to_s )
    end

    private

    # @return [Heron::Comet] Comet support.
    def comet
      @comet.()
    end

    # Emit verbose message.
    #
    # @param [String] s Message.
    # @return [undefined] undefined
    def verbose( s )
      @on_verbose.( s )
    end

    # Emit error message.
    #
    # @param [String] s Message.
    # @return [undefined] undefined
    def error( s )
      @on_error.( s )
    end

    # Access database.
    #
    # @return [DictionaryDB] Database.
    def database
      ::Heron::DictionaryDB.new( @db_path )
    end

    # Handle messages for a domain.
    #
    # @param [String] domain message are for.
    # @param [String] messages_json Messages in JSON.
    # @return [undefined] undefined
    def handle_messages_json( domain, messages_json )
      db = database
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
          verbose( "C #{domain}.#{key} = #{value}" )
          db.create_key( domain, key.to_s, value )
        when 'update'
          raise "Missing value." if ! value
          verbose( "U #{domain}.#{key} = #{value}" )
          db.update_key( value, domain, key.to_s )
        when 'delete'
          verbose( "D #{domain}.#{key}" )
          db.delete_key( domain, key.to_s )
        else
          raise "Invalid command: #{message['command']}"
        end
      end
    end
  end

  # Implements underlying database for Heron.Dictionary.
  #
  # The Dictionary is a set of domains, each of which is a set of key, value
  # pairs.  Alternately, the Dictionary is a map of [domain, key] to value.
  # Every client connects to a single session.  Each session contains one or
  # more domains.
  #
  # This class is fairly lowlevel.  It needs to be put together in a
  # controller such as SinatraDictionary.  In the future, this may be
  # rearranged.
  #
  # @!method clients_in_session( session_id )
  #   @param [String] session_id ID of session.
  #   @return [Array<String>] IDs of client in session.
  #
  # @!method other_clients_in_session_as( client_id )
  #   @param [String] client_id ID of client.
  #   @return [Array<String>] IDs of clients in same session as +client_id+.
  #
  # @!method create_key( domain, key, value )
  #   @param [String] domain  Domain of key.
  #   @param [String] key     Name of key.
  #   @param [String] value   Value of key.
  #   @return [undefined] undefined
  #
  # @!method update_key( value, domain, key )
  #   @param [String] value  Value to set to.
  #   @param [String] domain Domain of key to set.
  #   @param [String] key    Name of key to set.
  #   @return [undefined] undefined
  #
  # @!method delete_key( domain, key )
  #   @param [String] domain Domain of key to delete.
  #   @param [String] key    Name of key to delete.
  #   @return [undefined] undefined
  #
  # @!method all_key_values
  #   @return [Array<String, String, String, String>] List of of all
  #     [domain, key, value]
  #
  # @!method all_domains
  #   @return [Array<String>] List of all domains.
  #
  # @!method key_value( domain, key )
  #   @param [String] domain Domain of key.
  #   @param [String] key    Name of key.
  #   @return [Array<String>] value of key.
  #
  # @!method connect_client( client_id, session_id )
  #   @param [String] client_id  ID of client to connect.
  #   @param [String] session_id ID of session to connect to.
  #   @return [undefined] undefined
  #
  # @!method disconnect_clinet( client_id )
  #   @param [String] client_id ID of client to disconnect.
  #   @return [undefined] undefined
  #
  # @!method keys_in_domain( domain )
  #   @param [String] domain Domain to find keys of.
  #   @return [Array<String, String, String>] All [key, value]s in
  #     domain.
  #
  # @!method keys_for_client( client_id )
  #   @param [String] client_id ID of client to find keys of.
  #   @return [Array<String, String, String>] All [key, value]s for
  #     client.
  #
  # @!method add_domain( session_id, domain )
  #   @param [String] session_id Session to add domain to.
  #   @param [String] domain     Domain to add.
  #   @return [undefined] undefined
  #
  # @!method method remove_domain( session_id, domain )
  #   @param [String] session_id Session to remove domain from.
  #   @param [String] domain     Domain to remove.
  #   @return [undefined] undefined
  #
  # @!method sessions
  #   @return [Array<String, String>] All [session_id, domain] pairs.
  #
  class DictionaryDB
    protected
    # Add instance method +name+ corresponding to +query+.
    #
    # Queries will be prepared on first call.
    #
    # @param [String]  name   Name of method.
    # @param [String]  query  SQL Query to implement method.
    # @param [Boolean] single Set to true if querying a single column.
    # @return [undefined] undefined
    def self.prepare( name, query, single = false )
      s =
        "def #{name}( *args )\n" +
        "  @queries[\"#{name}\"] ||= @db.prepare( \"#{query}\" )\n" +
        "  result = @queries[\"#{name}\"].execute( *args )\n"
      if single
        s += "  result = result.collect {|x| x[0]};\n"
      end
      s += "end\n"

      class_eval( s )
    end

    public

    # @return [SQLite3::Database] Underlying database handle.
    attr_reader :db

    prepare(
      "clients_in_session",
      "SELECT id FROM clients WHERE session_id = ?",
      true
    )
    prepare(
      "other_clients_in_session_as",
      "SELECT DISTINCT a.id FROM clients AS a " +
      "JOIN sessions on a.session_id = sessions.id " +
      "JOIN clients AS b on sessions.id = b.session_id " +
      "WHERE b.id = ? AND a.id != b.id",
      true
    )
    prepare(
      "create_key",
      "INSERT OR REPLACE INTO key_values ( domain, key, value ) VALUES ( ?, ?, ?, ? )"
    )
    prepare(
      "update_key",
      "UPDATE key_values SET value = ? WHERE domain = ? AND KEY = ?"
    )
    prepare(
      "delete_key",
      "DELETE FROM key_values WHERE domain = ? AND key = ?"
    )
    prepare(
      'all_key_values',
      'SELECT domain, key, value FROM key_values'
    )
    prepare(
      'all_domains',
      'SELECT DISTINCT domain FROM key_values',
      true
    )
    prepare(
      'key_value',
      'SELECT value FROM key_values WHERE domain = ? AND key = ?',
      true
    )
    prepare(
      "connect_client",
      "INSERT OR REPLACE INTO clients ( id, session_id ) VALUES ( ?, ? )"
    )
    prepare(
      "disconnect_client",
      "DELETE FROM clients WHERE id = ?"
    )
    prepare(
      "keys_in_domain",
      "SELECT key, value FROM key_values " +
      "WHERE domain = ?"
    )
    prepare(
      "keys_for_client",
      "SELECT key_values.domain, key, value FROM key_values " +
      "JOIN sessions ON sessions.domain = key_values.domain " +
      "JOIN clients ON clients.session_id = sessions.id " +
      "WHERE clients.id = ?"
    )
    prepare(
      "add_domain",
      "INSERT OR REPLACE INTO sessions ( id, domain ) VALUES ( ?, ? )"
    )
    prepare(
      "remove_domain",
      "DELETE FROM sessions WHERE id = ? AND domain = ?"
    )
    prepare(
      "sessions",
      "SELECT id,domain FROM sessions"
    )

    # Constructor.
    #
    # @param [String] path Path to SQLite3 database file.
    def initialize( path )
      if path.is_a?( String )
        @db = SQLite3::Database.new( path )
      else
        @db = db
      end

      @queries = {}

      create
    end

    # Execute code as a single transaction.
    #
    # @yield Proc run within a tranasction.
    # @return Result of proc.
    def transaction( &p )
      @db.transaction( &p )
    end

    # Create database tables that do not exist.
    # @return [undefined] undefined
    def create
      @db.transaction do
        @db.execute(
          "CREATE TABLE IF NOT EXISTS sessions (
            id, domain
          )"
        )
        @db.execute(
          "CREATE INDEX IF NOT EXISTS idx_sessions_on_id " +
          "ON sessions (id)"
        )
        @db.execute(
          "CREATE UNIQUE INDEX IF NOT EXISTS idx_session_on_id_and_domain " +
          "ON sessions (id, domain)"
        )
        @db.execute(
          "CREATE TABLE IF NOT EXISTS clients (
            id, session_id,
            PRIMARY KEY (id),
            FOREIGN KEY (session_id) REFERENCES sessions (id)
          )"
        )
        @db.execute(
          "CREATE INDEX IF NOT EXISTS idx_clients_on_session_id " +
          "ON clients (session_id)"
        )
        @db.execute(
          "CREATE TABLE IF NOT EXISTS key_values (
            domain, key, value, 
            PRIMARY KEY (domain, key)
          )"
        )
      end
    end

  end
end
