require 'socket'
require 'hashie'
require 'json'
require 'uri'
require 'observer'
require 'pry'
require 'zlib'
require 'eventmachine'
require 'http/parser'

require_relative 'intervention/version'
require_relative 'intervention/server'
require_relative 'intervention/client'

Thread.abort_on_exception = true

module Intervention
  class << self

    def configure
      yield config
    end

    def start *args, **kwargs, &block
      EventMachine.start_server 'localhost', config.listen_port, Intervention::Client
    end

    def config
      @config ||= Hashie::Mash.new
    end
  end
end

thread = Thread.current
Thread.new{ EventMachine.run{ thread.wakeup } }
# pause until reactor starts
Thread.stop

Intervention.configure do |config|
  config.listen_port  = 2222
  config.host_address = 'localhost'
  config.host_port    = 80
end