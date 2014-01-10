module Intervention
  class Proxy
    class Transaction
      attr_reader :to_client, :to_server, :proxy
      attr_accessor :response, :request, :loopback

      Message = Struct.new(:type, :headers, :body, :header_order)

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
        @config    = proxy.config
        @loopback  = false
        @to_client = to_client
        @to_server = TCPSocket.new @config.host_address, @config.host_port
        @request   = Message.new("request", Hashie::Mash.new, Hashie::Mash.new, [])
        @response  = Message.new("response", Hashie::Mash.new, Hashie::Mash.new, [])

        receive_request
        unless @loopback
          send_request
          receive_response
        end
        send_response

        to_client.close
        to_server.close
        @state = "finished"
      end

      # Returns Boolean value on the transactions status
      #
      def in_request?
        @state == "in_request" ? true : false
      end

      # Returns Boolean value on the transactions status
      #
      def in_response?
        @state == "in_response" ? true : false
      end

      private

      def receive_request
        @state = "in_request"
        receive_headers to_client, request
        receive_body to_client, request

        # modify request host and accepted encoding to make life easy
        request.headers['host'] = @config.host_address
        request.headers['accept-encoding'] = "deflate,sdch"

        # call the request observers
        proxy.changed
        proxy.notify_observers(self, :request)
      end

      def send_request
        send_headers to_server, request
        send_body to_server, request
      end

      def receive_response
        @state = "in_response"
        receive_headers to_server, response
        receive_body to_server, response

        # call the response observers
        proxy.changed
        proxy.notify_observers(self, :response)
      end

      def send_response
        send_headers to_client, response
        send_body to_client, response
      end

      # read method for simplicity
      # @param socket [Socket] the socket that will be read from
      # @param size [Int] the size in bytes to read
      # ensures all read mesages are always stripped
      #
      def read socket, size = nil
        if size
          line = socket.read size.to_i+2
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

      # parse_request_line
      # @param socket [Socket] the socket that headers shall be received from
      # @param message [Message] the response or request
      # Reads in the request line
      # Goes through the request line and breaks it down with regex
      #
      def parse_request_line socket, message
        message.headers.request  = read socket

        if in_request?
          message.headers.verb   = message.headers.request[/^(\w+)\s(\/\S+)\sHTTP\/1.\d$/, 1]
          message.headers.url    = message.headers.request[/^(\w+)\s(\/\S+)\sHTTP\/1.\d$/, 2]
          message.headers.uri    = URI::parse @config.host_address + message.headers.url if @config.host_address && message.headers.url
        elsif in_response?
          message.headers.code   = message.headers.request[/^HTTP\/1.\d\s(\d+)\s(\w+)$/, 1]
          message.headers.status = message.headers.request[/^HTTP\/1.\d\s(\d+)\s(\w+)$/, 2]
        end
      end

      # receive_headers
      # @param socket [Socket] the socket that headers shall be received from
      # @param message [Message] the response or request
      # Collects and stores the headers of the message
      #
      def receive_headers socket, message
        parse_request_line socket, message

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
      end

      # send_headers
      # @param socket [Socket] the socket that body shall be collected from
      # @param message [Message] the response or request
      # Sends the message request line
      # Sends each of the headers in the order they were recived
      #
      def send_headers socket, message
        write socket, message.headers.request

        message.header_order.each do |header|
          write socket, header + ": " + message.headers[header]
        end

        write socket, ""
      end

      # receive_body
      # @param socket [Socket] the socket that body shall be collected from
      # @param message [Message] the response or request
      # Collects and stores the body of the message
      #
      def receive_body socket, message
        if message.headers.key? 'content-length'
          message.body.content = read socket, message.headers['content-length']
        elsif message.headers.key? 'transfer-encoding'
          case message.headers['transfer-encoding']
          when 'chunked'
            receive_chunked_content socket, message
          else
            raise "Unknown transfer-encoding: %s" % message.headers['transfer-encoding']
          end
        end
      end

      # send_body
      # @param socket [Socket] the socket that body shall be collected from
      # @param message [Message] the response or request
      # If the message has a content length only the content is sent
      # If the message has chunked content it is sent in chunked form
      #
      def send_body socket, message
        if message.header_order.include? 'content-length'
          write socket, message.body.content.to_json
          write socket, ""

        elsif message.header_order.include? 'transfer-encoding'
          case message.headers['transfer-encoding']
          when 'chunked'
            send_chunked_content socket, message
          else
            raise "Unknown transfer-encoding: %s" % message.headers['transfer-encoding']
          end
          write socket, ""
        end
      end

      # receive_chunked_content
      # @param socket [Socket] the socket that chunked data shall be collected from
      # @param message [Hashie::Mash] the response or request
      # Iterrates over the chunked content
      # Reads in the content size
      # Reads in the chunked content
      # Adds the chunked content to the body
      #
      def receive_chunked_content socket, message
        temp_content = ""

        loop do
          chunk_size = read(socket)
          break if chunk_size == "0"
          temp_content << read(socket, chunk_size.to_i(16))
        end
        message.body.update JSON.parse(temp_content) unless temp_content.empty?
      end

      # send_chunked_data
      # Converts the body to json
      # Sends body in large chunks
      #
      def send_chunked_content socket, message
        message.body.to_json.scan(/.{1,4000}/).each do |slice|
          write socket, slice.size.to_s(16)
          write socket, slice
        end
        write socket, "0"
      end

    end
  end
end