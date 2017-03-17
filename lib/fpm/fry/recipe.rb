require 'fpm/fry/source'
require 'fpm/fry/source/archive'
require 'fpm/fry/source/dir'
require 'fpm/fry/source/patched'
require 'fpm/fry/source/git'
require 'fpm/fry/plugin'
require 'fpm/fry/exec'
require 'shellwords'
require 'cabin'
module FPM; module Fry

  # A FPM::Fry::Recipe contains all information needed to build a package.
  #
  # It is usually created by {FPM::Fry::Recipe::Builder}.
  class Recipe

    # A FPM::Fry::Recipe::Step is a named build step.
    #
    # @see FPM::Fry::Recipe#steps
    class Step < Struct.new(:name, :value)
      def to_s
        value.to_s
      end
    end

    class PackageRecipe
      attr_accessor :name,
        :iteration,
        :version,
        :maintainer,
        :vendor,
        :depends,
        :provides,
        :conflicts,
        :replaces,
        :suggests,
        :recommends,
        :scripts,
        :output_hooks,
        :files


      def initialize
        @name = nil
        @iteration = nil
        @version = '0.0.0'
        @maintainer = nil
        @vendor = nil
        @depends = {}
        @provides = {}
        @conflicts = {}
        @replaces = {}
        @scripts = {
          before_install: [],
          after_install:  [],
          before_remove:  [],
          after_remove:   []
        }
        @output_hooks = []
        @files = []
      end

      alias dependencies depends

      # Applies settings to output package
      # @param [FPM::Package] package
      # @return [FPM::Package] package
      # @api private
      def apply_output( package )
        output_hooks.each{|h| h.call(self, package) }
        package.name = name
        package.version = version
        package.iteration = iteration
        package.maintainer = maintainer if maintainer
        package.vendor = vendor if vendor
        scripts.each do |type, scripts|
          package.scripts[type] = scripts.join("\n") if scripts.any?
        end
        [:dependencies, :conflicts, :replaces, :provides].each do |sym|
          send(sym).each do |name, options|
            constr = Array(options[:constraints])
            if constr.any?
              constr.each do | c |
                package.send(sym) << "#{name} #{c}"
              end
            else
              package.send(sym) << name
            end
          end
        end
        return package
      end

      alias apply apply_output

      # @api private
      SYNTAX_CHECK_SHELLS = ['/bin/sh','/bin/bash', '/bin/dash']

      # Lints the settings for some common problems
      # @return [Array<String>] problems
      def lint
        problems = []
        problems << "Name is empty." if name.to_s == ''
        scripts.each do |type,scripts|
          next if scripts.none?
          s = scripts.join("\n")
          if s == ''
            problems << "#{type} script is empty. This will produce broken packages."
            next
          end
          m = /\A#!([^\n]+)\n/.match(s)
          if !m
            problems << "#{type} script doesn't have a valid shebang"
            next
          end
          begin
            args = m[1].shellsplit
          rescue ArgumentError => e
            problems << "#{type} script doesn't have a valid command in shebang"
          end
          if SYNTAX_CHECK_SHELLS.include? args[0]
            begin
              Exec::exec(args[0],'-n', stdin_data: s)
            rescue Exec::Failed => e
              problems << "#{type} script is not valid #{args[0]} code: #{e.stderr.chomp}"
            end
          end
        end
        return problems
      end
    end

    # @return [FPM::Fry::Source] the source used for building
    attr_accessor :source

    attr_accessor :build_mounts

    # @return [Array<#to_s>] steps that will be carried out before dependencies are installed
    attr_accessor :before_dependencies_steps

    # @return [Array<#to_s>] steps that will be carried out before build
    attr_accessor :before_build_steps

    # @return [Array<#to_s>] steps that will be carried out during build
    attr_accessor :steps

    # @return [Array<FPM::Fry::PackageRecipe>] a list of packages that will be created
    attr_accessor :packages

    # @return [Hash<String,Hash>] build dependencies
    attr_accessor :build_depends

    # @return [Array<#call>] hooks that will be called on the input package
    attr_accessor :input_hooks

    # @return [Array<#call>] hooks that will be called when building the Dockerfile
    attr_accessor :dockerfile_hooks

    def initialize
      @source = Source::Null
      @before_dependencies_steps = []
      @before_build_steps = []
      @steps = []
      @packages = [PackageRecipe.new]
      @packages[0].files << '**'
      @build_depends = {}
      @input_hooks = []
      @dockerfile_hooks = []
      @build_mounts = []
    end

    # Calculates all dependencies of this recipe
    # @return [Hash<String,Hash>] the dependencies
    def depends
      depends = @packages.map(&:depends).inject(:merge)
      @packages.map(&:name).each do | n |
        depends.delete(n)
      end
      return depends
    end

    # Checks all packages for common errors
    # @return [Array<String>] problems
    def lint
      packages.flat_map(&:lint)
    end

    # Applies input settings to package
    # @param [FPM::Package] package
    # @return [FPM::Package]
    def apply_input( package )
      input_hooks.each{|h| h.call(self, package) }
      return package
    end

    # Filters the dockerfile
    # @api experimental
    # @param [Hash] df
    def apply_dockerfile_hooks( df )
      dockerfile_hooks.each do |hook|
        hook.call(self, df)
      end
      return nil
    end

  end

end ; end
