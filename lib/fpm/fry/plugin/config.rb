require 'fpm/fry/plugin'
module FPM::Fry::Plugin::Config

  # @api private
  IMPLICIT = Module.new

  # @api private
  MARK_EXPLICIT = Module.new do
    def self.call(_, package)
      package.attributes[:fry_config_explicitly_used] = true
    end
  end

  # @api private
  class Callback < Struct.new(:files)

    def call(_, package)
      prefix_length = package.staging_path.size + 1
      candidates = []
      # Sorting is important so that more specific rules override more generic 
      # rules.
      keys = files.keys.sort_by(&:size)
      keys.each do | key |
        if files[key]
          # Inclusion rule. Crawl file system for candidates
          begin
            Find.find( File.expand_path(key, package.staging_path) ) do | path |
              next unless File.file? path
              name = path[prefix_length..-1]
              candidates << name
            end
          rescue Errno::ENOENT
            package.logger.warn("Config path not found",
                                path: key,
                                documentation: 'https://github.com/xing/fpm-fry/wiki/Plugin-config#config-path-not-found')
          end
        else
          # Exclusion rule. Remove matching candidates
          keydir = key + "/"
          candidates.reject!{ |can| 
            can.start_with?(keydir) || can == key
          }
        end
      end
      package.config_files |= candidates
    end

  end

  class DSL < Struct.new(:builder, :options, :callback)

    def initialize( builder, options )
      callback = builder.output_hooks.find{|h| h.kind_of? Callback }
      if !callback
        callback = Callback.new({'etc' => true})
        builder.output_hooks << callback
      end
      # This looks kind of dirty. The callback tells the cook comamnd that the 
      # user has explictly used the config plugin. This way the cook command 
      # can hint the user to use this plugin if config files were automatically 
      # added.
      if !options[IMPLICIT]
        builder.output_hooks << MARK_EXPLICIT
      end
      super( builder, options, callback )
    end

    def include( path )
      if path[0] == "/"
        path = path[1..-1]
      end
      callback.files[path] = true
    end

    def exclude( path )
      if path[0] == "/"
        path = path[1..-1]
      end
      callback.files[path] = false
    end

  end

  def self.apply( builder, options = {}, &block )
    dsl = DSL.new(builder, options)
    if block
      if block.arity == 1
        yield dsl
      else
        dsl.instance_eval(&block)
      end
    end
    dsl
  end

end
