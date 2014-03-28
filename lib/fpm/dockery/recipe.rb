
module FPM; module Dockery

  class Recipe

    module ClassMethods

      # Internal foo
      def from_file(file)
        new.instance_eval(IO.read(file),file,0)
      end

      # DSL

    end

    extend ClassMethods

  end

end ; end
