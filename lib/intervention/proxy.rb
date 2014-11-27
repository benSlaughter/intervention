module Intervention
  class ProxyConnection  < EventMachine::Connection
    def initialize(*args, **kwargs)
      super
      @client  = kwargs[:client]
      @request = kwargs[:request]
      @logger  = kwargs[:logger]
      @logger.info('New proxy instance created')
    end

    def post_init
      EM::enable_proxy(@client, self)
      EM::enable_proxy(self, @client)
    end

    def connection_completed
      send_data @request
    end

    def proxy_target_unbound
      @logger.info('Proxy target disconnected')
      close_connection_after_writing
    end

    def unbind
      @logger.info('Proxy disconnected')
      @client.close_connection_after_writing
    end
  end
end