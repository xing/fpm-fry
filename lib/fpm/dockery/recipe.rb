require 'fpm/dockery/source'
require 'fpm/dockery/source/package'
require 'shellwords'
module FPM; module Dockery

  class Recipe

    Not = Module.new

    class Builder < Struct.new(:variables, :recipe)

      def distribution
        variables[:distribution]
      end

      def distribution_version
        variables[:distribution_version]
      end

      def initialize( vars, recipe = Recipe.new)
        vars.freeze
        super
      end

      def load_file( file )
        instance_eval(IO.read(file),file,0)
      end

      def version(value = Not)
        get_or_set('@version',value)
      end

      def name(value = Not)
        get_or_set('@name',value)
      end

      def build_depends( name , options = {} )
        recipe.depends[name] = options.merge(install: true, build: true)
      end

      def depends( name , options = {} )
        recipe.depends[name] = options
      end

      def source( url , options = {} )
        # super simple now
        get_or_set('@source',Source::Package.new(url, options))
      end

      def run(command, *args)
        recipe.steps[command] = Shellwords.join([command, *args])
      end

    protected
      def get_or_set(name, value = Not)
        if value == Not
          return recipe.instance_variable_get(name)
        else
          return recipe.instance_variable_set(name, value)
        end
      end
    end

    attr :name,
      :source,
      :depends,
      :suggests,
      :provides,
      :conflicts,
      :steps

    def initialize
      @name = nil
      @source = Source::Null
      @depends = {}
      @suggests = {}
      @provides = {}
      @conflicts = {}
      @steps = {}
    end

  end

end ; end
