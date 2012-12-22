#!/usr/bin/env ruby1.9

require 'rubygems'
require 'sinatra'

$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))
require 'server/sinatra_comet'
require 'server/sinatra_dictionary'

# Initialize Dictionary Database
DICTIONARY_DB = '/tmp/heron_dictionary'

Thread.abort_on_exception = true

# Example server for Heron.Dictionary.
class DictionaryServer < Sinatra::Base
  # Not a good idea in production.
  set :public_folder, File.expand_path(File.join(File.dirname(__FILE__), '..'))
  enable :static
  enable :threaded
  enable :run
  enable :dump_errors
  enable :logging
  use Rack::CommonLogger

  # Defines
  # /comet/connect
  # /comet/disconnect
  # /comet/receive
  # /comet/flush
  include ::Heron::SinatraComet

  # Path to dictionary; used by SinatraDictionary.
  DICTIONARY_DB_PATH = DICTIONARY_DB
  # Defines
  # /dictionary/subscribe
  # /dictionary/messages
  include ::Heron::SinatraDictionary

  dictionary.on_verbose   = -> s     { puts "DICT #{s}"                   }
  dictionary.on_error     = -> s     { puts "DICT ERROR #{s}"             }
  dictionary.on_subscribe = -> id, s { puts "DICT SUBSCRIBE [#{id}] #{s}" }
  dictionary.on_collision = -> s     { puts "DICT COLLISION #{s}"         }
  dictionary.create('example_dictionary', 'loc', '{"x":200, "y":200}', 'initial')

  comet.enable_debug

  comet.on_connect    = -> client_id { puts "COMET CONNECT #{client_id}"    }
  comet.on_disconnect = -> client_id { puts "COMET DISCONNECT #{client_id}" }

  get '/' do
    redirect '/example/dictionary.html'
  end

  at_exit { dictionary.shutdown }

  run!
end

# Work around Sinatra bug.
exit
