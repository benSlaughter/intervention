require 'socket'
require 'hashie'
require 'json'
require 'uri'

require './lib/intervention/proxy'
require './lib/intervention/packet'

module Intervention
  class << self
    attr_accessor :listen_port, :host_address, :host_port, :auto_start

    # Configure Interventions default values
    #
    # Intervention.configure do |i|
    #   i.listen_port = 4000
    #   i.host_address = "www.google.com"
    # end
    #
    # [listen_port = Integer]   The default listening port for the proxy server socket
    # [host_address = String]   The default address for the forward socket to send to
    # [host_port = Integer]     The default port number for the forward socket to send to
    # [auto_start = Boolean]    Whether to automaticly start the proxy upon creation
    #
    def configure
      yield self
    end

    # Creates a new proxy object
    # yields the configuration block if one is present
    #
    # Intervention.new_proxy "my_proxy", listen_port: 4000, host_address: "www.google.com"
    #
    # Intervention.new_proxy "my_proxy" do |proxy|
    #   proxy.listen_port = 4000
    #   proxy.host_address = "www.google.com"
    # end
    #
    def new_proxy name, **kwargs
      proxy = Proxy.new name, kwargs
      proxies << proxy
      yield proxy if block_given?
      proxy.start if Intervention.auto_start || kwargs[:auto_start]
      proxy
    end

    # Start all proxies within Intervention
    #
    def start_all
      proxies.each { |proxy| proxy.start }
    end

    # Stop all proxies within Intervention
    #
    def stop_all
      proxies.each { |proxy| proxy.stop }
    end

    def proxies
      @proxies ||= []
    end
  end
end

def me
  prox = Intervention.new_proxy "name", auto_start: true do |pr|
    pr.listen_port = 2222
    pr.host_port = 80
    pr.host_address = 'newapi.int.brandwatch.com'
  end
end