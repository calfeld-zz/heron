#!/usr/bin/env ruby1.9

require 'rubygems'
require 'sinatra'

$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))
require 'server/sinatra_comet'

# Example server for Heron.Comet.
class CometServer < Sinatra::Base
  # Not a good idea in production.
  set :public_folder, File.expand_path(File.join(File.dirname(__FILE__), '..'))
  set :static, true
  set :threaded, true
  set :run, true
  set :dump_errors, true
  enable :logging
  use Rack::CommonLogger

  # Defines
  # /comet/connect
  # /comet/disconnect
  # /comet/receive
  # /comet/flush
  include ::Heron::SinatraComet

  comet.enable_debug

  comet.on_connect = -> client_id do
    puts "CONNECT #{client_id}"
  end

  comet.on_disconnect = -> client_id do
    puts "DISCONNECT #{client_id}"
  end

  post '/comet_example' do
    client_id = params['client_id']
    message = params['message']

    # Forward message to all other clients.
    comet.each do |other_client_id|
      if other_client_id != client_id
        comet.queue(other_client_id, message)
      end
    end
  end

  get '/' do
    redirect '/example/comet.html'
  end

  run!
end

# Work around Sinatra bug.
exit
