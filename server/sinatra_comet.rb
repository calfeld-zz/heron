#!/usr/bin/env ruby1.9

# Examplish Sintra support for Heron::Comet.
#
# This files defines the Heron::SinatraComet that can included into a
# Sinatra::Base subclass to define a Heron::Comet controller.  For simple
# applications, it should suffice.  For more complex applications, or
# non-Sinatra servers, SinatraComet can serve as example of how to connect
# HTTP requests to Comet operations.
#
# Author::    Christopher Alfeld (calfeld@calfeld.net)
# Copyright:: Copyright (c) 2012 Christopher Alfeld

require 'server/comet'

module Heron

# Mixin for Sinatra::Base subclass to add comet support.
#
# By default, sets up the comet controller at "/comet/...".  This path can
# be changed by defining a class constant, COMET_PREFIX, *before* including
# this mixin.
#
# A single Heron::Comet instance is created for the *class* which will be
# shared by each instance.  This behavior is necessary as Sinatra will
# instantiate the base for each request and comet state must persist across
# requests.
#
# The Heron::Comet object can be accessed via the class or instance method
# #comet.  This method can be used to configure, e.g.,
#
#   class MyServer < Sinatra::Base
#     include Heron::SinatraComet
#
#     comet.on_connect = -> client_id { ... }
#     ...
#   end
#
# Routes created by default (see above):
# - get /comet/connect
# - get /comet/disconnect
# - get /comet/receive
# - get /comet/flush
#
# See also Heron::Comet
#
module SinatraComet
  # Add class commands, instantiate Heron::Comet, setup routes.
  def self.included(base)
    base.extend(ClassCommands)

    if ! base.const_defined?(:COMET_PREFIX)
      base.const_set(:COMET_PREFIX, "/comet")
    end

    base.class_variable_set(:@@comet, Heron::Comet.new())

    prefix = base.const_get(:COMET_PREFIX)

    base.get prefix + '/connect' do
      client_id = params['client_id']

      comet.connect(client_id)
    end

    base.get prefix + '/disconnect' do
      client_id = params['client_id']

      comet.disconnect(client_id)
    end

    base.get prefix + '/receive' do
      client_id = params['client_id']

      message = comet.receive(client_id)
      message.nil? ? "" : message
    end

    base.get prefix + '/flush' do
      client_id = params['client_id']

      # Flush any existing receive.
      comet.queue(client_id, "")
      200
    end
  end

  protected
  # Methods added to class.
  module ClassCommands
    protected
    # Access shared Heron::Comet object.
    def comet
      class_variable_get(:@@comet)
    end
  end

  # Access shared Heron::Comet object.
  def comet
    self.class.class_variable_get(:@@comet)
  end
end

end
