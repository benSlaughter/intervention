module Intervention
  class Transaction
    attr_reader :to_client, :to_server, :proxy
    attr_accessor :response, :request

    def inspect
      "#<Transaction:%s>" % [@state]
    end

    def initialize proxy, to_client
      @proxy     = proxy
      @to_client = to_client
      @to_server = TCPSocket.new proxy.host_address, proxy.host_port
      @request   = Hashie::Mash.new
      @response  = Hashie::Mash.new
      @state     = "ready"
    end

    def initiate
      # request
      @state = "collecting_request"
      collect_headers to_client, request
      collect_body to_client, request

      # modify request host and accepted encoding
      request.headers['host'] = proxy.host_address
      request.headers['accept-encoding'] = "deflate,sdch" if request.headers['accept-encoding']

      puts "[%s:%d] >>> [%s:%d]" % [ to_client.peeraddr[2], to_client.peeraddr[1], to_server.peeraddr[2], to_server.peeraddr[1]]
      @state = "collected_request"
      proxy.on_request.call(self) if proxy.on_request
      send to_server, request

      # response
      @state = "collecting_response"
      collect_headers to_server, response
      collect_body to_server, response

      puts "[%s:%d] <<< [%s:%d]" % [ to_client.peeraddr[2], to_client.peeraddr[1], to_server.peeraddr[2], to_server.peeraddr[1]]
      @state = "collected_response"
      proxy.on_response.call(self) if proxy.on_response
      send to_client, response

      @state = "closing_sockets"
      to_client.close
      to_server.close
      @state = "ended"
    end

    private

    def send socket, message
      # send headers
      write socket, message.headers.request

      message.header_order.each do |o|
        write socket, o + ": " + message.headers[o]
      end

      # finished sending headers
      write socket, ""

      # send body
      if message.header_order.include? 'content-length'
        write socket, message.body.content
        # finished sending body
        socket.write ""

      elsif message.header_order.include? 'transfer-encoding'
        case message.headers['transfer-encoding']
        when 'chunked'
          message.body.content.scan(/.{1,4000}/).each do |slice|
            write socket, slice.size.to_s(16)
            write socket, slice
          end
          write socket, "0"
        end
        # finished sending body
        write socket, ""

      end
    end

    def collect_headers socket, message
      message.header_order = []
      request_line = read socket

      message.headers         = Hashie::Mash.new
      message.headers.request = request_line
      message.headers.verb    = request_line[/^(\w+)+/, 1]
      message.headers.url     = request_line[/^\w+\s+(\S+)/, 1]
      message.headers.version = request_line[/HTTP\/(1\.\d)/, 1]
      message.headers.code    = request_line[/^HTTP\/1\.\d (\d+)/, 1]
      message.headers.status  = request_line[/^HTTP\/1\.\d \d+ (\w+)/ ,1]
      # message.headers.uri     = URI::parse message.headers.url if message.headers.url

      loop do
        line = read socket

        if line =~ /^proxy/i
          next
        elsif line.strip.empty?
          break
        else
          key, value = line.split ": "
          message.headers[key.downcase] = value
          message.header_order << key.downcase
        end
      end
      message.headers
    end

    def collect_body socket, message
      message.body = Hashie::Mash.new

      if message.header_order.include? 'content-length'
        message.body.content = read socket, message.headers['content-length']

      elsif message.header_order.include? 'transfer-encoding'
        case message.headers['transfer-encoding']
        when 'chunked'
          get_chunked_content socket, message
        end
      end
      message.body
    end

    def get_chunked_content socket, message
      content = ""

      loop do
        chunk_size = read socket
        break if chunk_size == '0'
        content << read(socket, chunk_size.to_i(16)+2)
      end
      message.body.content = content unless content.empty?
    end

    def dismantle_content message
      if message.headers['content-type'].include? "application/json"
        temp = Hashie::Mash.new
        temp.update JSON.parse message.body.content
        body.simple = temp
      end
    end

    # read write methods for simplicity
    # ensures all read mesages are always stripped
    # ensures all sent messages are always tailed
    #
    def read socket, size = nil
      if size
        line = socket.read size.to_i
      else
        line = socket.readline "\r\n"
      end
      line.chomp "\r\n"
    end

    def write socket, message
      socket.write message.to_s + "\r\n"
    end
  end
end