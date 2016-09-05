module FPM ; module Fry

  # Annotates an arbitrary exception with logable data.
  # 
  # @example
  #   raise FPM::Fry::WithData("Something went wrong", key: "value")
  # @param [String,Exception] ex
  # @param [Hash] data
  # @return [Exception] annotated exception
  #
  def self.WithData(ex, data)
    if ex.kind_of? String
      ex = StandardError.new(ex)
    end
    ex.define_singleton_method(:data){ data }
    return ex
  end

end ; end
