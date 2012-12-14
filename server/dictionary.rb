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
  # @todo Extract non-Sinatra specific parts of SinatraDictionary into
  #       Dictionary.
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
  #   @param [String] domain Domain of key.
  #   @param [String] key    Name of key.
  #   @param [String] value  Value of key.
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
  #   @return [Array<String, String, String>] List of of all
  #     [domain, key, value]
  #
  # @!method all_domains
  #   @return [Array<String>] List of all domains.
  #
  # @!method key_value( domain, key )
  #   @param [String] domain Domain of key.
  #   @param [String] key    Name of key.
  #   @return [String] Value of key.
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
  #   @return [Array<String, String>] All [key, value]s in domain.
  #
  # @!method keys_for_client( client_id )
  #   @param [String] client_id ID of client to find keys of.
  #   @return [Array<String, String>] All [key, value]s for client.
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
  class Dictionary
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
      "INSERT OR REPLACE INTO key_values ( domain, key, value ) VALUES ( ? , ? , ? )"
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
      "INSERT OR REPLACE INTO clients ( id, session_id ) VALUES ( ? , ? )"
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
