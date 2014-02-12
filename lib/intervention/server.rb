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
      Intervention.servers << self
      @parser = Segregate.new(self, debug: true)
    end

    def receive_data data
      @parser.parse_data data
    end

    def on_message_complete parser
      callback :response

      @client.send_data @parser.raw_data
      @client.close_connection_after_writing
      self.close_connection
      Intervention.servers.delete self
    end

    def unbind
      @client.close_connection_after_writing if @client
      self.close_connection
    end

    private

    def callback event
      Intervention.event_handlers[event].call(self) if Intervention.event_handlers.key? event
      Intervention.callbacks.each { |c| c.send(event, self) if c.respond_to? event }
    end
  end
end