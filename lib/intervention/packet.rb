module Intervention
  class Packet
    attr_reader :header_order
    attr_accessor :headers, :body, :true

    def initialize socket, proxy
      @socket = socket
      @proxy = proxy
      collect_headers socket
      collect_body socket
    end

    def send socket
      # send headers
      socket.write headers.request + trail

      header_order.each do |o|
        socket.write o + ": " + headers[o] + trail
      end

      # finished sending headers
      socket.write trail

      # send body
      if header_order.include? 'content-length'
        socket.write body.content + trail
        socket.write trail

      elsif header_order.include? 'transfer-encoding'
        case headers['transfer-encoding']
        when 'chunked'
          body.content.scan(/.{1,1000}/).each do |slice|
            socket.write slice.size.to_s(16) + trail
            socket.write slice + trail
          end
          socket.write "0" + trail
        end
        socket.write trail
      end
    end

    def rebuild_content
      body.content = body.simple.to_json
    end

    private

    def collect_headers socket
      @header_order = []
      request_line = socket.readline.chomp("\r\n")

      @headers         = Hashie::Mash.new
      headers.request = request_line
      headers.verb    = request_line[/^(\w+)+/, 1]
      headers.url     = request_line[/^\w+\s+(\S+)/, 1]
      headers.version = request_line[/HTTP\/(1\.\d)/, 1]
      headers.code    = request_line[/^HTTP\/1\.\d (\d+)/, 1]
      headers.status  = request_line[/^HTTP\/1\.\d \d+ (\w+)/ ,1]
      # headers.uri     = URI::parse headers.url if headers.url

      loop do
        line = socket.readline.chomp("\r\n")

        if line =~ /^proxy/i
          next
        elsif line.strip.empty?
          break
        else
          key, value = line.split ": "
          headers[key.downcase] = value
          @header_order << key.downcase
        end
      end
      headers
    end

    def collect_body socket
      @body = Hashie::Mash.new

      if header_order.include? 'content-length'
        body.content = socket.read(headers['content-length'].to_i)
        # dismantle_content

      elsif header_order.include? 'transfer-encoding'
        case headers['transfer-encoding']
        when 'chunked'
          get_chunked_content socket
          # dismantle_content
        end
      end

      body
    end

    def get_chunked_content socket
      body.content = ""

      loop do
        chunk_size = socket.readline.chomp("\r\n")
        break if chunk_size == '0'
        temp = socket.read(chunk_size.to_i(16)+2)
        body.content << temp.chomp("\r\n")
      end

      body
    end

    def dismantle_content
      if headers['content-type'].include? "application/json"
        temp = Hashie::Mash.new
        temp.update JSON.parse body.content
        body.simple = temp
      end
    end

    def debug message
      puts message if @proxy.debug
    end

    def trail
      "\r\n"
    end

    def content_length
      body.content ? body.content.length.to_s : nil
    end

    def body_content
      body.simple.to_json
    end
  end
end