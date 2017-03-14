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

    def method_missing(meth, *args, **kwargs, &block)
      if config.respond_to? meth
        config.send meth, *args, **kwargs, &block
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      config.respond_to?(method_name) || super
    end

    def start *args, **kwargs, &block
      raise 'you must specify at least one port' unless any_port_configured?

      start_http_server if config.port
      start_https_server if config.tls_port
    end

    def start_http_server
      EventMachine.start_server(
          'localhost',
          config.port,
          Intervention::Client
      )
    end

    def start_https_server
      raise 'you must specify a private key file' unless config.private_key_file
      raise 'you must specify a certificate file' unless config.cert_chain_file

      EventMachine.start_server(
          'localhost',
          config.tls_port,
          Intervention::Client,
          config
      )
    end

    def any_port_configured?
      config.port || config.tls_port
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

    def requests_to_block
      @config.requests_to_block ||= []
    end
  end
end

thread = Thread.current
Thread.new{ EventMachine.run{ thread.wakeup } }
# pause until reactor starts
Thread.stop
