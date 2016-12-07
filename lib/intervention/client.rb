module Intervention
  class Client < EventMachine::Connection
    attr_reader :server, :parser, :enable_tls

    def initialize(config = nil)
      activate_https_if_needed(config)

      super
    end

    def activate_https_if_needed(config)
      # for http server the config will be nil
      return unless config

      @enable_tls = true
      @config     = config
    end

    def inspect
      "#<Client:%s listen:%s>" % [(object_id << 1).to_s(16), Intervention.port]
    end

    def post_init
      Intervention.clients << self
      @parser = Segregate.new(self, debug: true)

      if @enable_tls
        start_tls(private_key_file: @config.private_key_file,
                  cert_chain_file: @config.cert_chain_file,
                  verify_peer: false)
      end
    end

    def receive_data data
      @parser.parse_data data
    end

    def on_message_complete parser
      return if blocked_request?

      callback :request

      host = @parser.headers['host'][/([^\:]*)(?:\:|$)/,1]
      port = @parser.headers['host'][/(?:\:)(\d+)/,1]

      port = @enable_tls ? 443 : 80 if port.nil?

      @server = EventMachine.connect host, port, Intervention::Server, client: self

      return if @enable_tls

      @server.send_data @parser.raw_data
      Intervention.clients.delete self
    end

    def unbind
      @server.close_connection_after_writing if @server
      self.close_connection
    end

    private

    def callback event
      Intervention.event_handlers[event].call(self) if Intervention.event_handlers.key? event
      Intervention.callbacks.each { |c| c.send(event, self) if c.respond_to? event }
    end

    def blocked_request?
      return false unless Intervention.requests_to_block.include?(@parser.path)

      self.close_connection
      Intervention.clients.delete self
      true
    end
  end
end
