module Intervention
  class Proxy
    class EventHandler
      attr_reader :config

      def initialize proxy, event, block
        @config = Hashie::Mash.new event: event, block: block, proxy: proxy
        proxy.add_observer self
      end

      def update transaction, event
        if event == @config.event
          @config.block.call transaction
        end
      end
    end
  end
end