#!/usr/bin/env ruby1.9

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

# Underlying server-side support for Heron.Comet.
#
# This file defines Heron::Comet, a class to do the server side state
# management for Heron.Comet.  It should be used in conjunction with a
# controller, e.g., Heron::SinatraComet, and the client side library,
# Heron.Comet.  Alternately, it could be reused in an alternative Comet
# implementation.  The key features are ruby and thread based.
#
# Running this file directly will execute some basic unit tests.
#
# Author::    Christopher Alfeld (calfeld@calfeld.net)

require 'set'
require 'thread'

# Module for all server side Heron code.
module Heron

  # Comet Related Errors
  class CometError < RuntimeError
  end

  # This class handles the basic logic and thread queues for comet support.
  # It is intended to be run as part of a threaded, single process,
  # web server.
  #
  # Each client connects via #connect.  This establishes a queue for the
  # client.  Messages can now be sent to the client via #queue.  The client,
  # should call #receive in a loop to wait for messages: the loop is likely
  # a client side javascript loop issuing Ajax requests which in turn call
  # #receive.
  #
  # Clients can explicitly disconnect via #disconnect but are also implicitly
  # disconnected if they do not call receive within +client_timeout+ seconds.
  # To facilitate this, #receive itself times out after +receive_timeout+
  # sessions, returning null.  +receive_timeout+ should be shorter than
  # +client_timeout+.
  #
  # Handlers for client connections and disconnections can be registered.
  #
  class Comet
    private

    def hcd
      if ! @@debug.nil?
        now = Time.now.to_f
        @@debug.puts "HCD(%d %.2f %.2f): %s" % [
          Thread.current.object_id,
          now-@@debug_start,
          now-@@debug_last,
          yield
        ]
        @@debug_last = now
      end
    end

    # Per-client info.
    ClientInfo = Struct.new(
      :queue,         # Interthread queue.
      :heartbeat,     # Last time #receive called.  Use for client timeout.
      :lock,          # Receive lock.  Ensures single receiver at a time.
      :monitor_queue, # Queue used to kill monitor thread.
      :monitor        # Heartbeat monitoring thread.
    )

    # Mark a client as active.  Used to detect disconnects.
    def touch_client( client_id )
      @clients[ client_id ].heartbeat = Time.now
    end

    # Special exception used to implement timeouts.
    class TimeoutError < Exception
    end

    public

    # @return [Proc] Connect handler.
    attr_accessor :on_connect
    # @return [Proc] Disconnect handler.
    attr_accessor :on_disconnect
    # @return [FixNum] Client timeout handler.
    attr_accessor :client_timeout
    # @return [FixNum] Receive timeout handler.
    attr_accessor :receive_timeout

    include Enumerable

    # Turn on debugging.
    #
    # @param [IO] to Where to write debug info.
    # @return [self] self
    def enable_debug(to = STDOUT)
      @@debug = to
      @@debug_last = Time.now.to_f
      @@debug_start = @@debug_last
      hcd{"Debugging Enabled"}
      self
    end

    # Constructor.
    #
    # @param [Hash] args Arguments.
    # @option args [Proc] :on_connect Proc to call with client_id on
    #   connect.
    # @option args [Proc] :on_disconnect Proc to call with client_id on
    #   disconnect.
    # @option args [FixNum] :client_timeout Seconds before implicit disconnect
    #   of client.
    # @option args [FixNum] :receive_timeout Timeout for {#receive}.
    def initialize( args = {} )
      bad = args.keys.to_set - [
        :on_connect, :on_disconnect, :client_timeout, :receive_timeout
      ].to_set
      raise CometError.new("Invalid argument(s): #{bad.to_a}") if ! bad.empty?

      @on_connect = args[ :on_connect ] || -> x {}
      @on_disconnect = args[ :on_disconnect ] || -> x {}
      @client_timeout = args[ :client_timeout ] || 60
      @receive_timeout = args[ :receive_timeout ] || 20

      @clients_lock = Mutex.new
      @clients = {}
    end

    # Receive next message for +client_id+.  Updates heartbeat at call time.
    # Will timeout, returning nil, if no message receive in +receive_timeout+
    # seconds.  Will return nil immediately on disconnect.  Will raise
    # exception if no such client.
    #
    # It is possible to have multiple receivers, but probably undesired.
    # A call to {#receive} when another call is ongoing will be delayed until
    # the original call completes.  As such, it is quite possible for a call
    # to block for a while and then raise an exception because the client has
    # disconnected.
    #
    # @param [String] client_id Client ID.
    # @return [String] message or nil
    def receive( client_id )
      hcd{"#{client_id}:receive"}

      info = @clients[ client_id ]
      raise CometError.new("No such client: #{client_id}") if ! info

      data = nil

      info.lock.synchronize do
        touch_client( client_id )

        # At the time of writing Thread.kill and, thus, Timeout don't quite
        # work.  So here's a specialized implementation.
        current = Thread.current
        timeout_flag = false

        data = nil

        hcd{"#{client_id}:receive:sleep"}
        timeout_thread = Thread.new do
          sleep @receive_timeout
          info.queue << nil if ! timeout_flag
        end

        data = info.queue.pop
        hcd{"#{client_id}:receive:" + (data.nil? ? "timeout" : data.inspect)}
        timeout_flag = true
      end

      hcd{"#{client_id}:receive:finished"}
      data
    end

    # Iterate through client ids.
    #
    # @yield [id] Yields each client id if passed proc.
    # @return [Array<String>] Array of IDs.
    def each
      @clients_lock.synchronize do
        if block_given?
          @clients.keys.each {|x| yield(x)}
        else
          @clients.keys.each
        end
      end
    end

    # Queue +message+ for +client_id+.  Will raise an exception if +client_id+
    # is not valid.  Unlike, {#receive}, it is perfectly acceptable to have
    # multiple threads queuing messages.
    #
    # @param [String] client_id Client to queue message for.
    # @param [String] message Message to queue.
    # @return [self] self
    def queue( client_id, message )
      hcd{"#{client_id}:queue:#{message}"}
      info = @clients[ client_id ]
      raise CometError.new("Invalid client_id: #{client_id}") if ! info

      info.queue << message

      hcd{"#{client_id}:queue:finished"}
      self
    end

    # True iff client_id is a client.
    #
    # @param [String] client_id String to check if client id.
    def client?( client_id )
      @clients_lock.synchronize do
        @clients[ client_id ] != nil
      end
    end

    # Connect a client with +client_id+.  If +client_id+ is already connected,
    # will simply update the heartbeat timestamp.  This behavior has been
    # much debated and could change in the future.
    #
    # @param [String] client_id Client ID to connect.
    # @return [self] self
    def connect( client_id )
      hcd{"#{client_id}:connect"}
      @clients_lock.synchronize do
        if @clients[ client_id ]
          touch_client( client_id )
        else
          info = @clients[ client_id ] = ClientInfo.new(
            Queue.new,
            Time.now,
            Mutex.new,
            Queue.new
          )
          info.monitor = Thread.new do
            while true
              sleep @client_timeout

              # Check if we should exit.
              if ! info.monitor_queue.empty?
                break
              end

              now = Time.now
              if now - info.heartbeat > @client_timeout
                disconnect( client_id )
              end
            end
          end
        end
      end

      @on_connect.( client_id )
      self
    end

    # Disconnects client +client_id+.  Has no effect if +client_id+ is not
    # valid.  This behavior has been much debated and could change in the
    # future.
    #
    # @param [String] client_id Client id to disconnect.
    # @return [self] self
    def disconnect( client_id )
      hcd{"#{client_id}:disconnect"}

      @clients_lock.synchronize do
        info = @clients[ client_id ]
        return if ! info

        @clients.delete( client_id )
        info.monitor_queue << nil # Ask monitor to exit.
        info.queue << nil # In case current listener exists.
      end

      @on_disconnect.( client_id )
    end

  end

end # module Heron

if __FILE__ == $0

  puts "Running unit tests.  Will throw an exception if anything goes wrong."
  Thread.abort_on_exception = true

  require File.dirname( File.expand_path( __FILE__ ) ) + "/assert"

  on_connect = nil
  on_disconnect = nil
  comet = Heron::Comet.new(
    :client_timeout => 3,
    :receive_timeout => 1,
    :on_connect => -> x { on_connect = x },
    :on_disconnect => -> x { on_disconnect = x }
  )

  # Basic smoke test.
  Thread.new do
    comet.connect( 1 )
    assert { on_connect == 1 }
    assert { comet.receive( 1 ) == :hello }
    assert { comet.receive( 1 ) == :world }
    assert { comet.receive( 1 ) == nil }
  end

  sleep 0.1 while ! comet.client?( 1 )
  comet.queue( 1, :hello )
  comet.queue( 1, :world )
  sleep 1
  comet.disconnect( 1 )
  assert { on_disconnect == 1 }

  assert_throw { comet.queue( 1, :fail ) }
  assert_throw { comet.receive( 1 ) }
  comet.disconnect( 1 )  # no exception

  # Receive timeout.
  on_connect = on_disconnect = nil
  comet.connect( 2 )
  assert { comet.receive( 2 ) == nil }
  sleep 4
  assert { on_disconnect == 2 }

end
