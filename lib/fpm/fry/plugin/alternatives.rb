require 'fpm/fry/plugin'
module FPM::Fry::Plugin::Alternatives

  BASH_HEADER = ['#!/bin/bash']
  DEFAULT_PRIORITY = 10000
  EXPECTED_KEYS    = [:path, :link, :priority]

  class DSL < Struct.new(:builder, :alternatives)

    def initialize( b, a = {})
      super
    end

    def []=(name, options={}, value)
      name = name.to_s
      if value.kind_of? String
        options = normalize(name, options.merge(path: value) )
      else
        options = normalize(name, options.merge(value) )
      end
      alternatives[name] = options
    end

    def add(name, value, options={})
      self[name, options] = value
    end

    def finish!
      install   = alternatives.map{|_,v|   install_command(v) }
      uninstall = alternatives.map{|_,v| uninstall_command(v) }
      builder.plugin('script_helper') do
        after_install_or_upgrade(*install)
        before_remove_entirely(*uninstall)
      end
    end

  private
    def normalize_without_slaves(name, options)
      if options.kind_of? String
        options = {path: options}
      elsif options.kind_of? Hash
        additional_keys = options.keys - EXPECTED_KEYS
        raise ArgumentError, "Unexpected options: #{additional_keys.inspect}" if additional_keys.any?
        options = options.dup
      else
        raise ArgumentError, "Options must be either a Hash or a String, got #{options.inspect}"
      end
      options[:name] = name
      options[:link] ||= File.join('/usr/bin',name)
      return options
    end

    def normalize( name, options )
      slaves  = {}
      if options.kind_of?(Hash) && options.key?(:slaves)
        options = options.dup
        slaves  = options.delete(:slaves)
      end
      options = normalize_without_slaves(name, options)
      options[:slaves] = slaves.map{|k,v| normalize_without_slaves(k, v) }
      options[:priority] ||= DEFAULT_PRIORITY
      return options
    end

    def install_command(options)
      slaves = options.fetch(:slaves,[]).flat_map{|options| ['--slave', options[:link],options[:name],options[:path]] }
      Shellwords.join(['update-alternatives','--install',options[:link],options[:name],options[:path],options[:priority].to_s, *slaves])
    end

    def uninstall_command(options)
      Shellwords.join(['update-alternatives','--remove',options[:name],options[:path]])
    end
  end

  def self.apply(builder, options = {}, &block)
    dsl = DSL.new(builder)
    options.each do |k,v|
      dsl.add(k,v)
    end
    if block
      if block.arity == 1 
        yield dsl
      else
        dsl.instance_eval(&block)
      end
    end
    dsl.finish!
  end

end
