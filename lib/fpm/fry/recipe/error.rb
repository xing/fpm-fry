require 'fpm/fry/recipe'
module FPM::Fry
  class Recipe
    class Error < StandardError

      attr :data

      def initialize(msg=nil, data={})
        super(msg)
        @data = data
      end

    end
  end
end
