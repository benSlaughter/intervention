module Intervention
  module Engine
    attr_reader :name

    def name
      @name.to_sym || :unnamed
    end

    def update transaction, *proxy_events
      proxy_events.each do |event|
        events[event].call(transaction) if events.respond_to? event
      end
    end

    private

    def name= name
      @name = name
    end

    def events
      @events ||= Hashie::Mash.new
    end

    def event event, m = :execute
      events[event] = method(m)
    end

  end
end