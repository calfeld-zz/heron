#!/usr/bin/env ruby1.9

require 'rubygems'
require 'sinatra'

$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))
require 'server/sinatra_comet'
require 'server/sinatra_dictionary'

# Initialize Dictionary Database
DICTIONARY_DB = '/tmp/heron_dictionary.db'
dictionary = ::Heron::Dictionary.new(DICTIONARY_DB)
dictionary.add_domain('example_dictionary', 'example_dictionary')
dictionary.create_key('example_dictionary', 'loc', '{"x":200, "y":200}')

class DictionaryServer < Sinatra::Base
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

  # Defines
  # /dictionary/connect
  # /dictionary/disconnect
  # /dictionary/messages
  include ::Heron::SinatraDictionary

  # Trace dictionary operations
  def dictionary_trace( s )
    puts "DICT #{s}"
  end

  # Location of database
  def dictionary_path
    DICTIONARY_DB
  end

  comet.enable_debug

  comet.on_connect = -> client_id do
    puts "CONNECT #{client_id}"
  end

  comet.on_disconnect = -> client_id do
    puts "DISCONNECT #{client_id}"
    # Important
    dictionary_disconnect( client_id )
  end

  get '/' do
    redirect '/example/dictionary.html'
  end

  run!
end

# Work around Sinatra bug.
exit
