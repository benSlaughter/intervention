require 'hashie'
require 'lumberjack'
require 'eventmachine'
require 'http_tools'
require 'json'

require_relative 'intervention/version'
require_relative 'intervention/client'
require_relative 'intervention/proxy'

Thread.abort_on_exception = true

module Intervention
  class << self

    def start *args, **kwargs, &block
      EventMachine.start_server 'localhost', config.listen_port, Intervention::Client, logger: logger
      logger.level = 0
    end

    def configure
      yield config
    end

    def logger
      @config.logger ||= Lumberjack::Logger.new('logs/intervention.log', :roll => :daily)
    end

    def config
      @config ||= Hashie::Mash.new
    end

    def clients
      @config.clients ||= []
    end

    def servers
      @config.servers ||= []
    end

    def target_address
      config.target_address
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
  config.target_address = 'localhost'
end