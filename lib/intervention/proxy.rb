Thread.abort_on_exception=true

module Intervention
  class Proxy
    attr_reader :name, :server_socket, :state
    attr_accessor :listen_port, :host_address, :host_port, :debug

    def initialize name, **kwargs
      @name = name
      @debug = true
      @state = "asleep"
      @listen_port = kwargs[:listen_port] || Intervention.listen_port
      @host_address = kwargs[:host_address] || Intervention.host_address
      @host_port = kwargs[:host_port] || Intervention.host_port
    end

    def on_request(&block); @on_request = block; end
    def on_response(&block); @on_response = block; end

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
          run_transaction new_socket
        end
      end

    rescue Interrupt
      puts "ERROR: Interrupt!"
    ensure
      @server_socket.close if @server_socket
      new_socket.close if defined? new_socket
      puts "Quitting #{@name}..."
    end

    def run_transaction to_client
      to_server = TCPSocket.new host_address, host_port

      # request
      request = Packet.new to_client, self
      request.headers['host'] = host_address
      request.headers['accept-encoding'] = "deflate,sdch" if request.headers['accept-encoding']
      puts "[%s:%d] >>> [%s:%d]" % [ to_client.peeraddr[2], to_client.peeraddr[1], to_server.peeraddr[2], to_server.peeraddr[1]]
      @on_request.call(request) if @on_request
      request.send to_server

      # response
      response = Packet.new to_server, self
      puts "[%s:%d] <<< [%s:%d]" % [ to_client.peeraddr[2], to_client.peeraddr[1], to_server.peeraddr[2], to_server.peeraddr[1]]
      @on_response.call(response) if @on_response
      response.send to_client

      to_client.close
      to_server.close
    end
  end
end