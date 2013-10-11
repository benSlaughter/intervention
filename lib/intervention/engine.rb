module Intervention
  module Engine
    attr_reader :status

    def name
      @name.to_sym || :unnamed
    end

    def update transaction, *proxy_events
      if status
        proxy_events.each do |event|
          events[event].call transaction if events.respond_to? event
        end
      end
    end

    def intervent!
      @status = true
    end

    private

    def events
      @events ||= Hashie::Mash.new
    end

    def event event, m = :execute
      events[event] = method(m)
    end

  end
end