module FPM ; module Fry

  def self.WithData(ex, data)
    ex.define_singleton_method(:data){ data }
    return ex
  end

end ; end
