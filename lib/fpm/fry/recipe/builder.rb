require 'fpm/fry/recipe'
require 'fpm/fry/recipe/error'
require 'forwardable'
require 'fpm/fry/channel'

module FPM::Fry
  class Recipe

    class NotFound < StandardError
    end

    class PackageBuilder

      # @return [Hash<Symbol,Object>]
      attr :variables

      # @return [FPM::Fry::PackageRecipe]
      attr :package_recipe

      # @return [Cabin::Channel]
      attr :logger

      # @return [FPM::Fry::Inspector,nil]
      attr :inspector

      # @api private
      def initialize( variables, package_recipe, options = {})
        @variables = variables
        @package_recipe = package_recipe
        @logger = options.fetch(:logger){ Cabin::Channel.get }
        @inspector = options[:inspector]
      end

      # Returns the package type ( e.g. "debian" or "redhat" ).
      # @return [String]
      def flavour
        variables[:flavour]
      end

      def distribution
        variables[:distribution]
      end
      alias platform distribution

      # The release version of the distribution ( e.g. "12.04" or "6.0.7" )
      # @return [String]
      def release
        variables[:release]
      end

      alias distribution_version release
      alias platform_version distribution_version

      def codename
        variables[:codename]
      end

      def architecture
        variables[:architecture]
      end

      def iteration(value = Not)
        get_or_set('@iteration',value)
      end
      alias revision iteration

      def version(value = Not)
        get_or_set('@version',value)
      end

      def name(value = Not)
        get_or_set('@name',value)
      end

      def vendor(value = Not)
        get_or_set('@vendor',value)
      end

      def depends( name , options = {} )
        name, options = parse_package(name, options)
        if package_recipe.depends.key? name
          raise Error.new("duplicate dependency",package: name)
        elsif package_recipe.conflicts.key? name
          raise Error.new("depending package is already a conflicting package",package: name)
        end
        package_recipe.depends[name] = options
      end

      def conflicts( name , options = {} )
        name, options = parse_package(name, options)
        if package_recipe.conflicts.key? name
          raise Error.new("duplicate conflict",package: name)
        elsif package_recipe.depends.key? name
          raise Error.new("conflicting package is already a dependency",package: name)
        end
        package_recipe.conflicts[name] = options
      end

      def provides( name , options = {} )
        name, options = parse_package(name, options)
        package_recipe.provides[name] = options
      end

      def replaces( name , options = {} )
        name, options = parse_package(name, options)
        package_recipe.replaces[name] = options
      end

      def files( pattern )
        package_recipe.files << pattern
      end

      def plugin(name, *args, &block)
        logger.debug('Loading Plugin', name: name, args: args, block: block, load_path: $LOAD_PATH)
        if name =~ /\A\./
          require name
        else
          require File.join('fpm/fry/plugin',name)
        end
        module_name = File.basename(name,'.rb').gsub(/(?:\A|_)([a-z])/){ $1.upcase }
        mod = FPM::Fry::Plugin.const_get(module_name)
        if mod.respond_to? :apply
          mod.apply(self, *args, &block)
        else
          if args.any? or block_given?
            raise ArgumentError, "Simple plugins can't accept additional arguments and blocks."
          end
          extend(mod)
        end
      end

      def script(type, value = Not)
        if value != Not
          package_recipe.scripts[type] << value
        end
        return package_recipe.scripts[type]
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
      alias before_uninstall before_remove
      alias pre_uninstall before_remove
      alias preuninstall before_remove

      def after_remove(*args)
        script(:after_remove, *args)
      end
      alias after_uninstall after_remove
      alias post_uninstall after_remove
      alias postuninstall after_remove

      def output_hooks
        package_recipe.output_hooks
      end

    protected

      def parse_package( name, options = {} )
        if options.kind_of? String
          options = {constraints: options}
        end
        case(v = options[:constraints])
        when String
          options[:constraints] = v.split(',').map do |c|
            if c =~ /\A\s*(<=|<<|>=|>>|<>|=|>|<)(\s*)/
              $1 + ' ' + $'
            else
              '= ' + c
            end
          end
        end
        return name, options
      end


      Not = Module.new
      def get_or_set(name, value = Not)
        if value == Not
          return package_recipe.instance_variable_get(name)
        else
          return package_recipe.instance_variable_set(name, value)
        end
      end

    end

    class Builder < PackageBuilder

      # @return [FPM::Fry::Recipe]
      attr :recipe

      # @param [Hash<Symbol,Object>] variables
      # @param [Hash] options
      # @option options [FPM::Fry::Recipe] :recipe (Recipe.new)
      # @option options [Cabin::Channel] :logger (default cabin channel)
      # @option options [FPM::Fry::Inspector] :inspector
      def initialize( variables, options = {} )
        recipe = options.fetch(:recipe){ Recipe.new }
        variables = variables.dup
        variables.freeze
        @recipe = recipe
        @steps = :steps
        register_default_source_types!
        super(variables, recipe.packages[0], options)
      end

      def load_file( file )
        file = File.expand_path(file)
        begin
          content = IO.read(file)
        rescue Errno::ENOENT => e
          raise NotFound, e
        end
        basedir = File.dirname(file)
        Dir.chdir(basedir) do
          instance_eval(content,file,0)
        end
      end

      def source( url , options = {} )
        options = options.merge(logger: logger)
        source = Source::Patched.decorate(options) do |options|
          guess_source(url,options).new(url, options)
        end
        recipe.source = source
      end

      def add(source, target)
        recipe.build_mounts << [source, target]
      end

      def apt_setup(cmd)
        before_dependencies do
          bash cmd
        end
      end

      def run(*args)
        if args.first.kind_of? Hash
          options = args.shift
        else
          options = {}
        end
        command = args.shift
        name = options.fetch(:name){ [command,*args].select{|c| c[0] != '-' }.join(' ') }
        bash( name, Shellwords.join([command, *args]) )
      end

      def bash( name = nil, code )
        if name
          code = Recipe::Step.new(name, code)
        end
        # Don't do this at home
        case(@steps)
        when :before_dependencies
          recipe.before_dependencies_steps << code
        when :before_build
          recipe.before_build_steps << code
        else
          recipe.steps << code
        end
      end

      def before_build
        steps, @steps = @steps, :before_build
        yield
      ensure
        @steps = steps
      end

      def before_dependencies
        steps, @steps = @steps, :before_dependencies
        yield
      ensure
        @steps = steps
      end

      def build_depends( name , options = {} )
        name, options = parse_package(name, options)
        recipe.build_depends[name] = options
      end

      def input_hooks
        recipe.input_hooks
      end

      def package(name, &block)
        pr = PackageRecipe.new
        pr.name = name
        pr.version = package_recipe.version
        pr.iteration = package_recipe.iteration
        recipe.packages << pr
        PackageBuilder.new(variables, pr, logger: logger, inspector: inspector).instance_eval(&block)
      end

      attr_reader :keep_modified_files

      def keep_modified_files!
        @keep_modified_files = true
      end

    protected

      def source_types
        @source_types  ||= {}
      end

      def register_source_type( klass )
        if !klass.respond_to? :new
          raise ArgumentError.new("Expected something that responds to :new, got #{klass.inspect}")
        end
        source_types[klass.name] = klass
        if klass.respond_to? :aliases
          klass.aliases.each do |al|
            source_types[al] = klass
          end
        end
      end

      def register_default_source_types!
        register_source_type Source::Git
        register_source_type Source::Archive
        register_source_type Source::Dir
      end

      NEG_INF = (-1.0/0.0)

      def guess_source( url, options = {} )
        if w = options[:with]
          return source_types.fetch(w){ raise ArgumentError.new("Unknown source type: #{w}") }
        end
        scores = source_types.values.uniq\
          .select{|klass| klass.respond_to? :guess }\
          .group_by{|klass| klass.guess(url) }\
          .sort_by{|score,_| score.nil? ? NEG_INF : score }
        score, klasses = scores.last
        if score == nil
          raise Error.new("No source provider found for #{url}.\nMaybe try explicitly setting the type using :with parameter. Valid options are: #{source_types.keys.join(', ')}")
        end
        if klasses.size != 1
          raise Error.new("Multiple possible source providers found for #{url}: #{klasses.join(', ')}.\nMaybe try explicitly setting the type using :with parameter. Valid options are: #{source_types.keys.join(', ')}")
        end
        return klasses.first
      end

    end
  end
end
