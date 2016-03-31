require 'fpm/fry/source'
require 'fpm/fry/source/package'
require 'fpm/fry/source/dir'
require 'fpm/fry/source/patched'
require 'fpm/fry/source/git'
require 'fpm/fry/plugin'
require 'fpm/fry/os_db'
require 'shellwords'
require 'cabin'
require 'open3'
module FPM; module Fry

  class Recipe

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

      def apply_output( package )
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
        output_hooks.each{|h| h.call(self, package) }
        return package
      end

      alias apply apply_output

      SYNTAX_CHECK_SHELLS = ['/bin/sh','/bin/bash', '/bin/dash']

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
            sin, sout, serr, th = Open3.popen3(args[0],'-n')
            sin.write(s)
            sin.close
            if th.value.exitstatus != 0
              problems << "#{type} script is not valid #{args[0]} code: #{serr.read.chomp}"
            end
            serr.close
            sout.close
          end
        end
        return problems
      end
    end

    attr_accessor :source,
      :before_build_steps,
      :steps,
      :packages,
      :build_depends,
      :input_hooks

    def initialize
      @source = Source::Null
      @before_build_steps = []
      @steps = []
      @packages = [PackageRecipe.new]
      @packages[0].files << '**'
      @build_depends = {}
      @input_hooks = []
    end

    def depends
      depends = @packages.map(&:depends).inject(:merge)
      @packages.map(&:name).each do | n |
        depends.delete(n)
      end
      return depends
    end

    def lint
      packages.flat_map(&:lint)
    end

    def apply_input( package )
      input_hooks.each{|h| h.call(self, package) }
      return package
    end

  end

end ; end
