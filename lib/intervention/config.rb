module Intervention
  class Config < Hashie::Mash
    def method_missing meth, *args, **kwargs, &block
      if self.key? meth
        super
      elsif Intervention.config.key? meth
        Intervention.config.send meth, *args, **kwargs, &block
      else
        super
      end
    end
  end
end