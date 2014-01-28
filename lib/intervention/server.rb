module Intervention
  class Server < EventMachine::Connection

    attr_reader :client, :parser, :response

    def inspect
      "#<Server:%s host:%s port:%s>" % [(object_id << 1).to_s(16), Intervention.config.host_address, Intervention.config.host_port]
    end

    def initialize *args, **kwargs, &block
      super
      @client = kwargs[:client]
    end

    def post_init
      Intervention.config.server = self
      @parser = Http::Parser.new(self)
    end

    def receive_data data
      @parser << data
    end

    def on_message_begin
      @response = Hashie::Mash.new
      @response.headers = Hashie::Mash.new
      @response.body = ''
    end

    def on_headers_complete(headers)
      @response.headers.update headers
    end

    def on_body(chunk)
      @response.body << chunk
    end

    def on_message_complete
      if @response.headers['Content-Encoding'] && @response.headers['Content-Encoding'] == "gzip"
        temp = ""
        gz = Zlib::GzipReader.new(StringIO.new(@response.body))
        gz.each do | line |
          temp << line
        end
        @response.body = temp
      end

      callback :response
      forward_response
    end

    private

     def callback event
      Intervention.event_handlers[event].call(self) if Intervention.event_handlers.key? event
      Intervention.callbacks.each { |c| c.send(event, self) if c.respond_to? event }
    end

    def status_line
      "HTTP/%d.%d %s" % [@parser.http_major, @parser.http_minor, @parser.status_code]
    end

    def forward_response
      @response.headers.delete("Transfer-Encoding")
      @response.headers['Content-Length'] = @response.body.length.to_s
      send_response
    end

    def send_response
      send status_line
      @response.headers.each do |key, value|
        send "%s: %s" % [key, value]
      end
      send ""
      unless @response.body.empty?
        send @response.body
      end
      send ""
    end

    def send data
      @client.send_data data + "\r\n"
    end
  end
end