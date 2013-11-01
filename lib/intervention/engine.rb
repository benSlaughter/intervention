module Intervention
  module Engine

    def name
      @name.to_sym || :unnamed
    end

    def update transaction, *proxy_events
      proxy_events.each do |event|
        if events.respond_to?(event)
          events[event].call(transaction)
        end
      end
    end

    def name= agent_name
      @name = agent_name
    end

    def events
      @events ||= Hashie::Mash.new
    end

    def event event, m = :execute
      events[event] = method(m)
    end

  end
end

module Intervention
  module Engine
    module ClassMethods

    end

    def self.included(receiver)
      receiver.extend         ClassMethods
    end
  end
end