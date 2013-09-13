module Intervention
  # Proxy
  # @attr_reader name [String] The proxies name
  # @attr_reader state [String] the current running state of the proxy
  # @attr_accessor listen_port The default listening port for the proxy server socket
  # @attr_accessor host_address The default address for the forward socket to send to
  # @attr_accessor host_port The default port number for the forward socket to send to
  #
  class Proxy
    attr_reader :name, :state, :interventions
    attr_accessor :listen_port, :host_address, :host_port

    # Overiting the default class inspect
    #
    def inspect
      "#<Proxy:%s:%s listen:%s host:%s port:%s>" % [@name,@state,@listen_port,@host_address,@host_port]
    end

    # Intervention::Proxy#initalize
    # @param name [String] the given name of the proxy
    # Keyword Arguments:
    # @param listen_port [Integer] The default listening port for the proxy server socket
    # @param host_address [Hash] The default address for the forward socket to send to
    # @param host_port [Integer] The default port number for the forward socket to send to
    #
    def initialize name, **kwargs
      @name          = name
      @state         = "asleep"
      @interventions = []
      @listen_port   = kwargs[:listen_port] || Intervention.listen_port
      @host_address  = kwargs[:host_address] || Intervention.host_address
      @host_port     = kwargs[:host_port] || Intervention.host_port
    end

    def load_interventions arry
      @interventions << arry
    end

    # Called upon a request being made
    # @returns [Proc] the stored request proc
    #
    def on_request(&block)
      block_given? ? @on_request = block : @on_request
    end

    # Called upon a response being made
    # @returns [Proc] the stored response proc
    #
    def on_response(&block)
      block_given? ? @on_response = block : @on_response
    end

    # Configure Proxy values
    #
    # proxy_object.configure do |proxy|
    #   proxy.listen_port = 4000
    #   proxy.host_address = "www.google.com"
    # end
    #
    # [listen_port = Integer]   The listening port for the proxy server socket
    # [host_address = String]   The address for the forward socket to send to
    # [host_port = Integer]     The port number for the forward socket to send to
    #
    def configure
      yield self
    end

    # Start Proxy
    # creates starts the proxy server in a thread
    # returns control to the caller
    #
    def start
      @server_socket = TCPServer.new @listen_port
      @state = "socket_created"

      Thread.new do
        run_proxy
      end
    end

    # Stop proxy
    # Stops the server socket
    #
    def stop
      @server_socket.close
      @state = "stopped"
    end

    private

    # Run proxy method, that is run within the thread
    # Passes self, self is the proxy
    #
    def run_proxy
      loop do
        @state = "awaiting_connection"
        new_socket = @server_socket.accept
        @state = "new_connection"

        Thread.new do
          Transaction.new(self, new_socket).initiate
        end
      end

    ensure
      @server_socket.close if @server_socket
      new_socket.close if defined? new_socket
      puts "Quitting #{@name}..."
    end
  end
end