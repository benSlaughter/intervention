module Intervention
  # Proxy
  # @attr_reader name [String] The proxies name
  # @attr_reader state [String] the current running state of the proxy
  # @attr_accessor listen_port The default listening port for the proxy server socket
  # @attr_accessor host_address The default address for the forward socket to send to
  # @attr_accessor host_port The default port number for the forward socket to send to
  #
  class Proxy
    include Observable

    attr_reader :name, :config

    # Overiting the default class inspect
    #
    def inspect
      "#<Proxy:%s:%s listen:%s host:%s port:%s>" % [@name, @config.state, @config.listen_port, @config.host_address, @config.host_port]
    end

    # Intervention::Proxy#initalize
    # @param name [String] the given name of the proxy
    # Keyword Arguments:
    # @param listen_port [Integer] The default listening port for the proxy server socket
    # @param host_address [Hash] The default address for the forward socket to send to
    # @param host_port [Integer] The default port number for the forward socket to send to
    #
    def initialize name, **kwargs, &block
      @name            = name
      @config          = Intervention.config.merge Hashie::Mash.new(kwargs)
      @config.state    = "stopped"
      @config.handlers = []

      instance_eval(&block) if block_given?
      start if @config.auto_start
    end

    # Returns Boolean value on the proxies status
    #
    def stopped?
      @config.state == "stopped" ? true : false
    end

    # Returns Boolean value on the proxies status
    #
    def running?
      @config.state == "running" ? true : false
    end

    # Configure Proxy values
    #
    # proxy_object.configure do |config|
    #   config.listen_port = 4000
    #   config.host_address = "www.google.com"
    # end
    #
    # [listen_port = Integer]   The listening port for the proxy server socket
    # [host_address = String]   The address for the forward socket to send to
    # [host_port = Integer]     The port number for the forward socket to send to
    #
    def configure
      yield @config
    end

    # Start Proxy
    # creates starts the proxy server in a thread
    # returns control to the caller
    #
    def start
      if stopped?
        @config.state = "running"
        @server_socket = TCPServer.new @config.listen_port
        @main_loop = Thread.new { _run_proxy }
      end
    end

    # Stop proxy
    # Stops the server socket
    #
    def stop
      if running?
        @main_loop.kill
        @server_socket.close
        @config.state = "stopped"
      end
    end

    # Creates an event using the passed block
    # @param event [Symbol] the name of the event
    # @param block [Proc] the block that is run upon the event being triggered
    #
    def on event, &block
      _register_event_handler event, block
    end

    private

    def _register_event_handler event, block
      @config.handlers << EventHandler.new(self, event, block)
    end

    # Method that starts the thread and loops the proxy
    # Passes self (proxy) into each transaction
    # Ensures that all sockets are closed in the event of an error
    #
    def _run_proxy
      loop do
        new_socket = @server_socket.accept
        Thread.new { Transaction.new(self, new_socket) }
      end

    ensure
      puts "Quitting proxy #{@name}..."
      @server_socket.close if @server_socket
      new_socket.close if defined? new_socket
    end
  end
end