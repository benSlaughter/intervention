module Intervention
  class Proxy
    class EventHandler
      attr_reader :proxy, :config

      def initialize proxy, event, block
        proxy.add_observer self
        @config = Config.new event: event, block: block
      end

      def update transaction, event
        if event == @config.event
          @config.block.call transaction
        end
      end
    end
  end
end