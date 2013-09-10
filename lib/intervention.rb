require 'intervention/proxy'
require 'intervention/transaction'

module Intervention
  class << self
    def new_proxy port = nil
    end

    def configure
      yield self
    end

    def start_all
    end

    def stop_all
    end
  end
end