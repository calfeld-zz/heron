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
# You must mixin SinatraComet before this mixin.
#
# You must define a class constant, DICTIONARY_DB_PATH, containing the path to
# the database file (will create if non-existant) *before* including this
# mixin.
#
# By default, sets up the dictionary controller at "/dictionary/...".  This
# path can be changed by defining a class constant, DICTIONARY_PREFIX,
# *before* including this mixin.
#
# Provides a protect class and instance method, `dictionary`, that returns the
# shared {Heron::Dictionary} instance.  This can be used to further configure
# Dictionary.
#
# You should have your {Comet} disconnect handler, call
# {Dictionary#disconnect}.
#
# Routes created by default (see above):
# - post /dictionary/connect
# - post /dictionary/disconnect
# - post /dictionary/messages
#
# @see Dictionary
#
module SinatraDictionary
  # Setup routes.
  def self.included(base)
    base.extend(ClassCommands)

    if ! base.const_defined?(:DICTIONARY_PREFIX)
      base.const_set(:DICTIONARY_PREFIX, "/dictionary")
    end

    prefix = base.const_get(:DICTIONARY_PREFIX)

    if ! base.const_defined?(:DICTIONARY_DB_PATH)
      raise "Must defined :DICTIONARY_DB_PATH before mixin."
    end
    db_path = base.const_get(:DICTIONARY_DB_PATH)

    base.class_variable_set(:@@dictionary, Heron::Dictionary.new(
      db_path: db_path,
      comet:   -> {base.send(:comet)}
    ))

    base.post prefix + '/connect' do
      client_id  = params[ 'client_id' ]
      session_id = params[ 'session_id' ]

      raise "Missing client_id." if ! client_id
      raise "Missing session_id." if ! session_id

      dictionary.connect( client_id, session_id )
      200
    end

    base.post prefix + '/disconnect' do
      client_id = params[ 'client_id' ]

      raise "Missing client_id." if ! client_id

      dictionary.disconnect( client_id )
      200
    end

    base.post prefix + '/messages' do
      client_id = params[ 'client_id' ]
      messages  = params[ 'messages' ]

      raise "Missing client_id." if ! client_id
      raise "Missing messages."  if ! messages

      dictionary.messages( client_id, messages )
      200
    end
  end

  protected
  # Methods added to class.
  module ClassCommands
    protected
    # Access shared Heron::Dictionary object.
    def dictionary
      class_variable_get(:@@dictionary)
    end
  end

  # Access shared Heron::Dictionary object.
  def dictionary
    self.class.class_variable_get(:@@dictionary)
  end
end

end
