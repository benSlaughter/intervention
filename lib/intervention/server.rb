module Intervention
  class Server < EventMachine::Connection

    attr_reader :client, :parser

    def inspect
      "#<Server:%s host:%s port:%s>" % [(object_id << 1).to_s(16), Intervention.config.host_address, Intervention.config.host_port]
    end

    def initialize *args, **kwargs, &block
      super
      @client = kwargs[:client]
    end

    def post_init
      Intervention.config.server = self
      @parser = Segregate.new(self)
    end

    def receive_data data
      @parser.parse data
    end

    def on_message_complete
      callback :response

      @response.headers.delete("Transfer-Encoding")
      @response.headers['Content-Length'] = @response.body.length.to_s
      @client.send_data @parser.raw_data
    end

    private

    def callback event
      Intervention.event_handlers[event].call(self) if Intervention.event_handlers.key? event
      Intervention.callbacks.each { |c| c.send(event, self) if c.respond_to? event }
    end
  end
end