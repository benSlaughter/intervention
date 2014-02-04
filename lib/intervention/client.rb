module Intervention
  class Client < EventMachine::Connection

    attr_reader :server, :parser

    def inspect
      "#<Client:%s listen:%s>" % [(object_id << 1).to_s(16), Intervention.config.listen_port]
    end

    def post_init
      Intervention.config.client = self
      @parser = Segregate.new(self)
      @server = EventMachine.connect Intervention.config.host_address, Intervention.config.host_port, Intervention::Server, client: self
    end

    def receive_data data
      @parser.parse data
    end

    def on_body_complete parser
      callback :request

      @parser.headers['host'] = Intervention.config.host_address
      @request.headers['accept-encoding'] = "deflate"
      @server.send_data @parser.raw_data
    end

    private

    def callback event
      Intervention.event_handlers[event].call(self) if Intervention.event_handlers.key? event
      Intervention.callbacks.each { |c| c.send(event, self) if c.respond_to? event }
    end
  end
end