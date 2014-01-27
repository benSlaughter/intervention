module Intervention
  class Server < EventMachine::Connection

    attr_reader :client

    def inspect
      "#<Server:%s host:%s port:%s>" % [(object_id << 1).to_s(16), Intervention.config.host_address, Intervention.config.host_port]
    end

    def initialize *args, **kwargs, &block
      super
      @client = kwargs[:client]
    end

    def post_init
      Intervention.config.server = self
      @http_parser = Http::Parser.new(self)
    end

    def receive_data data
      puts "RECEIVED FROM SERVER"
      @http_parser << data
      @client.send_data data
    end

    def on_message_begin
      @headers = nil
      @body = ''
    end

    def on_headers_complete(headers)
      @headers = headers
      p headers
    end

    def on_body(chunk)
      @body << chunk
    end

    def on_message_complete
      if @headers['Content-Encoding'] && @headers['Content-Encoding'] == "gzip"
        temp = ""
        gz = Zlib::GzipReader.new(StringIO.new(@body))
        gz.each do | line |
          temp << line
        end
        @body = temp
      end

      puts @body
    end
  end
end