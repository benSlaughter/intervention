module Intervention
  class Client < EventMachine::Connection
    attr_reader :server, :parser

    HEADERS = {
      "Access-Control-Allow-Headers" => "Content-Type",
      "Access-Control-Allow-Methods" => "GET, POST, DELETE, PUT",
      "Access-Control-Allow-Origin"  => "*",
      "Content-Type"                 => "application/json;charset=UTF-8",
      "Connection"                   => "keep-alive",
      "Transfer-Encoding"            => "deflate"
    }
    CLOSE = "\r\n\r\n"

    def inspect
      "#<Client:#{(object_id << 1).to_s(16)} listen:#{Intervention.config.listen_port}>"
    end

    def initialize *args, **kwargs, &block
      super
      @logger   = kwargs[:logger]
      @proxy    = false
      @raw_data = ""
      @parser   = HTTPTools::Parser.new
      @parser.on(:header) { headers_complete }
      @parser.on(:finish) { message_complete unless @proxy}

      Intervention.clients << self
      @logger.info('New client instance created')
    end

    def receive_data data
      @logger.debug('--- data received ---')
      @logger.debug(data)
      @raw_data << data
      @parser << data
    end

    def unbind
      @logger.info('Client disconnected')
      close_connection_after_writing
      Intervention.clients.delete self
    end

    private

    def headers_complete
      @logger.debug('Headers completed')
      return nil if @parser.header['Host'].include? Intervention.target_address
      setup_proxy
    end

    def message_complete
      @logger.info('Request received')

      # get stored json
      body = {id: 265500, username: 'adminuser=bens@brandwatch.com'}.to_json

      # build headers
      headers = HEADERS.merge("Content-Length" => body.length.to_s)

      # build final message
      message = HTTPTools::Builder.response(200, headers)

      send_data(message + body + CLOSE)
      close_connection_after_writing
    end

    def setup_proxy
      @proxy = true

      host = @parser.header['Host'][/([^\:]*)(?:\:|$)/,1]
      port = (@parser.header['Host'][/(?:\:)(\d+)/,1] || 80)

      p host
      p port

      EventMachine.connect(
        host,
        port,
        ProxyConnection,
        client: self,
        request: @raw_data,
        logger: @logger
      )
    end
  end
end