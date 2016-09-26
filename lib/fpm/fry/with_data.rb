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

  # Adds a data method to an exception. This overrides initialize so it may 
  # not work everywhere.
  module WithData

    # @return [Hash] debugging/logging data
    attr :data

    def initialize(e=self.class.name, data = {})
      if e.kind_of? Exception
        if e.respond_to? :data
          @data = e.data.merge(data)
        else
          @data = data.dup.freeze
        end
        super(e.message)
      else
        @data = data.dup.freeze
        super(e.to_s)
      end
    end
  end

end ; end
