module Intervention
  class Client < EventMachine::Connection

    attr_reader :server, :parser, :request

    def inspect
      "#<Client:%s listen:%s>" % [(object_id << 1).to_s(16), Intervention.config.listen_port]
    end

    def post_init
      Intervention.config.client = self
      @parser = Http::Parser.new(self)
      @server = EventMachine.connect Intervention.config.host_address, Intervention.config.host_port, Intervention::Server, client: self
    end

    def receive_data data
      data.sub!("Host: localhost:", "Host: #{Intervention.config.host_address}:")
      @parser << data
    end

    def on_message_begin
      @request = Hashie::Mash.new
      @request.headers = Hashie::Mash.new
      @request.body = ''
    end

    def on_headers_complete(headers)
      @request.headers.update headers
    end

    def on_body(chunk)
      @request.body << chunk
    end

    def on_message_complete
      if @request.headers['Content-Encoding'] && @request.headers['Content-Encoding'] == "gzip"
        temp = ""
        gz = Zlib::GzipReader.new(StringIO.new(@request.body))
        gz.each do | line |
          temp << line
        end
        @request.body = temp
        @request.headers.delete('Content-Encoding')
      end

      callback :request
      forward_request
    end

    private

    def callback event
      Intervention.event_handlers[event].call(self) if Intervention.event_handlers.key? event
      Intervention.callbacks.each { |c| c.send(event, self) if c.respond_to? event }
    end

    def request_line
      "%s %s HTTP/%d.%d" % [@parser.http_method, @parser.request_url, @parser.http_major, @parser.http_minor]
    end

    def forward_request
      @request.headers['Host'] = Intervention.config.host_address
      @request.headers['Accept-Encoding'] = "deflate"
      send_request
    end

    def send_request
      send request_line
      @request.headers.each do |key, value|
        send "%s: %s" % [key, value]
      end
      send ""
      unless @request.body.empty?
        send @request.body
      end
      send ""
    end

    def send data
      @server.send_data data + "\r\n"
    end
  end
end