module Intervention
  class Client < EventMachine::Connection

    attr_reader :server

    def inspect
      "#<Client:%s listen:%s>" % [(object_id << 1).to_s(16), Intervention.config.listen_port]
    end

    def post_init
      Intervention.config.client = self
      @http_parser = Http::Parser.new(self)
      @server = EventMachine.connect Intervention.config.host_address, Intervention.config.host_port, Intervention::Server, client: self
    end

    def receive_data data
      puts "RECEIVED FROM CLIENT"
      data.sub!("Host: localhost:", "Host: #{Intervention.config.host_address}:")
      @http_parser << data
      @server.send_data data
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