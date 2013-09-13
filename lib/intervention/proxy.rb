Thread.abort_on_exception=true

module Intervention
  class Proxy
    attr_reader :name, :state
    attr_accessor :listen_port, :host_address, :host_port, :debug

    def inspect
      "#<Proxy:%s listen:%s host:%s port:%s>" % [@state,@listen_port,@host_address,@host_port]
    end

    def initialize name, **kwargs
      @name         = name
      @debug        = true
      @state        = "asleep"
      @listen_port  = kwargs[:listen_port] || Intervention.listen_port
      @host_address = kwargs[:host_address] || Intervention.host_address
      @host_port    = kwargs[:host_port] || Intervention.host_port
    end

    def on_request(&block); block_given? ? @on_request = block : @on_request; end
    def on_response(&block); block_given? ? @on_response = block : @on_response; end

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

    def start
      @server_socket = TCPServer.new @listen_port
      @state = "socket_created"

      Thread.new do
        run_proxy
      end
    end

    def stop
      @server_socket.close
      @state = "stopped"
    end

    private

    def run_proxy
      loop do
        @state = "awaiting_connection"

        new_socket = @server_socket.accept
        @state = "connecton_accepted"

        Thread.new do
          Transaction.new(self, new_socket).initiate
        end
      end

    ensure
      @server_socket.close if @server_socket
      new_socket.close if defined? new_socket
      puts "Quitting #{@name}..."
    end

    def __class__
    end
  end
end