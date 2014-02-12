require 'socket'
require 'hashie'
require 'json'
require 'uri'
require 'observer'
require 'pry'
require 'zlib'
require 'eventmachine'
require 'segregate'

require_relative 'intervention/version'
require_relative 'intervention/server'
require_relative 'intervention/client'

Thread.abort_on_exception = true

module Intervention
  class << self

    def method_missing meth, *args, **kwargs, &block
      if config.respond_to? meth
        config.send meth, *args, **kwargs, &block
      else
        super
      end
    end

    def start *args, **kwargs, &block
      EventMachine.start_server 'localhost', config.listen_port, Intervention::Client
    end

    def configure
      yield config
    end

    def on event, &block
      @config.event_handlers ||= Hashie::Mash.new
      @config.event_handlers[event] = block
    end

    def callback object
      @config.callbacks ||= []
      @config.callbacks << object
    end

    def config
      @config ||= Hashie::Mash.new
    end

    def event_handlers
      @config.event_handlers ||= Hashie::Mash.new
    end

    def callbacks
      @config.callbacks ||= []
    end

    def clients
      @config.clients ||= []
    end

    def servers
      @config.servers ||= []
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