require 'fpm/dockery/source'
require 'fpm/dockery/source/package'
require 'shellwords'
module FPM; module Dockery

  class Recipe

    Not = Module.new

    class Builder < Struct.new(:variables, :recipe)

      def flavour
        variables[:flavour]
      end

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
        if options.kind_of? String
          options = {version: options}
        end
        recipe.build_depends[name] = options
      end

      def depends( name, options = {} )
        if options.kind_of? String
          options = {version: options}
        end
        recipe.depends[name] = options
      end

      def source( url , options = {} )
        # super simple now
        get_or_set('@source',Source::Package.new(url, options))
      end

      def run(*args)
        if args.first.kind_of? Hash
          options = args.shift
        else
          options = {}
        end
        command = args.shift
        name = options.fetch(:name){ [command,*args].select{|c| c[0] != '-' }.join('-') }
        recipe.steps[name] = Shellwords.join([command, *args])
      end

      def script(type, value)
        recipe.scripts[type] << value
      end

      def before_install(*args)
        script(:before_install, *args)
      end
      alias pre_install before_install
      alias preinstall before_install

      def after_install(*args)
        script(:after_install, *args)
      end
      alias post_install after_install
      alias postinstall after_install

      def before_remove(*args)
        script(:before_remove, *args)
      end
      alias pre_uninstall before_remove
      alias preuninstall before_remove

      def after_remove(*args)
        script(:after_remove, *args)
      end
      alias post_uninstall after_remove
      alias postuninstall after_remove

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
      :version,
      :maintainer,
      :vendor,
      :source,
      :build_depends,
      :depends,
      :suggests,
      :provides,
      :conflicts,
      :steps,
      :scripts

    def initialize
      @name = nil
      @source = Source::Null
      @version = '0.0.0'
      @maintainer = nil
      @vendor = nil
      @build_depends = {}
      @depends = {}
      @suggests = {}
      @provides = {}
      @conflicts = {}
      @steps = {}
      @scripts = {
        before_install: [],
        after_install:  [],
        before_remove:  [],
        after_remove:   []
      }
    end

    def apply( package )
      package.name = name
      package.version = version
      package.maintainer = maintainer if maintainer
      package.vendor = vendor if vendor
      scripts.each do |type, scripts|
        package.scripts[type] = scripts.join("\n") if scripts.any?
      end
      depends.each do |name, options|
        package.dependencies << "#{name}#{options[:version]}"
      end
      return package
    end

  end

end ; end
