module Intervention
  class Transaction
    attr_reader :to_client, :to_server, :proxy
    attr_accessor :response, :request

    # Overiting the default class inspect
    #
    def inspect
      "#<Transaction:%s>" % [@state]
    end

    # initialize Transaction
    # @param proxy [Proxy] the proxy the transaction belongs to
    # @param to_client [Socket] the socket that was made by the server
    # creates the socket required to complete the proxy
    #
    def initialize proxy, to_client
      @proxy     = proxy
      @to_client = to_client
      @to_server = TCPSocket.new proxy.host_address, proxy.host_port
      @request   = Hashie::Mash.new
      @response  = Hashie::Mash.new
      @state     = "ready"
    end

    # initiate
    # starts the transaction
    # and cleans up once completed
    #
    def initiate
      request_magic
      response_magic

      to_client.close
      to_server.close
      @state = "ended"
    end

    private

    # request_magic
    # deals with the request part of the transactions
    #
    def request_magic
      @state = "in_request"
      collect_headers to_client, request
      collect_body to_client, request

      # modify request host and accepted encoding to make life easy
      request.headers['host'] = proxy.host_address
      request.headers['accept-encoding'] = "deflate,sdch" if request.headers['accept-encoding']

      # call the on_request methods
      proxy.on_request.call(self) if proxy.on_request
      proxy.interventions.each { |i|  i.on_request self if i.respond_to? 'on_request' }

      send to_server, request
    end

    # response_magic
    # deals with the response part of the transaction
    #
    def response_magic
      @state = "in_response"
      collect_headers to_server, response
      collect_body to_server, response

      # call the on_response methods
      proxy.on_response.call(self) if proxy.on_response
      proxy.interventions.each { |i|  i.on_response self if i.respond_to? 'on_response' }

      send to_client, response
    end

    # send
    # @param socket [Socket] the socket that the message will be sent to
    # @param message [Hashie::Mash] the response or request to send
    # sends the given message down the given socket
    # sends the data as it was recived
    #
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

    # collect_headers
    # @param socket [Socket] the socket that headers shall be collected from
    # @param message [Hashie::Mash] the response or request
    # assesses the message and collects the headers
    # also breaks apart the request message and stores the information
    #
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
      message.headers.uri     = URI::parse proxy.host_address + message.headers.url if message.headers.url && proxy.host_address

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

    # collect_body
    # @param socket [Socket] the socket that body shall be collected from
    # @param message [Hashie::Mash] the response or request
    # assessed the body and then collects the data
    #
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

    # get_chunked_content
    # @param socket [Socket] the socket that chunked data shall be collected from
    # @param message [Hashie::Mash] the response or request
    # if the body of a message contains chunked content
    # this reads the chunk size
    # then reads in that data
    # once all collected the body content is updated
    def get_chunked_content socket, message
      content = ""

      loop do
        chunk_size = read socket
        break if chunk_size == '0'
        content << read(socket, chunk_size.to_i(16)+2)
      end
      message.body.content = content unless content.empty?
    end

    # dismante_content
    # @param message [Hashie::Mash] the response or request
    # if the content is json then parses the body content and store
    #
    def dismantle_content message
      if message.headers['content-type'].include? "application/json"
        temp = Hashie::Mash.new
        temp.update JSON.parse message.body.content
        message.body.simple = temp
      end
    end

    # read method for simplicity
    # @param socket [Socket] the socket that will be read from
    # @param size [Int] the size in bytes to read
    # ensures all read mesages are always stripped
    #
    def read socket, size = nil
      if size
        line = socket.read size.to_i
      else
        line = socket.readline "\r\n"
      end
      line.chomp "\r\n"
    end

    # write method for simplicity
    # @param socket [Socket] the socket that message will be written to
    # @param message [String] the message to write to the socket
    # ensures all sent messages are always tailed
    #
    def write socket, message
      socket.write message.to_s + "\r\n"
    end
  end
end