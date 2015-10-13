require 'fiber'
require 'shellwords'
require 'rubygems/package'
require 'fpm/fry/os_db'
require 'fpm/fry/source'
require 'fpm/fry/joined_io'
module FPM; module Fry
  class DockerFile < Struct.new(:variables,:cache,:recipe)

    NAME = 'Dockerfile.fpm-fry'

    class Source < Struct.new(:variables, :cache)

      def initialize(variables, cache = Source::Null::Cache)
        variables = variables.dup
        if variables[:distribution] && !variables[:flavour] && OsDb[variables[:distribution]]
          variables[:flavour] = OsDb[variables[:distribution]][:flavour]
        end
        variables.freeze
        super(variables, cache)
      end

      def dockerfile
        df = []
        df << "FROM #{variables[:image]}"

        df << "RUN mkdir /tmp/build"

        cache.file_map.each do |from, to|
          df << "ADD #{map_from(from)} #{map_to(to)}"
        end

        df << ""
        return df.join("\n")
      end

      def tar_io
        JoinedIO.new(
          self_tar_io,
          cache.tar_io
        )
      end

      def self_tar_io
        sio = StringIO.new
        tar = Gem::Package::TarWriter.new(sio)
        tar.add_file(NAME,'0777') do |io|
          io.write(dockerfile)
        end
        #tar.close
        sio.rewind
        return sio
      end

      def map_to(dir)
        if ['','.'].include? dir
          return '/tmp/build'
        else
          return File.join('/tmp/build',dir)
        end
      end

      def map_from(dir)
        if dir == ''
          return '.'
        else
          return dir
        end
      end

    end

    class Build < Struct.new(:base, :variables, :recipe)

      attr :options
      private :options

      def initialize(base, variables, recipe, options = {})
        variables = variables.dup
        if variables[:distribution] && !variables[:flavour] && OsDb[variables[:distribution]]
          variables[:flavour] = OsDb[variables[:distribution]][:flavour]
        end
        variables.freeze
        @options = options.dup.freeze
        super(base, variables, recipe)
      end

      def dockerfile
        df = []
        df << "FROM #{base}"
        df << "WORKDIR /tmp/build"

        deps = (recipe.build_depends.merge recipe.depends)\
          .select{|_,v| v.fetch(:install,true) }\
          .map do |k,v|
            i = v.fetch(:install,true)
            if i == true then
              k
            else
              i
            end
          end.sort
        if deps.any?
          case(variables[:flavour])
          when 'debian'
            update = ''
            if options[:update]
              update = 'apt-get update && '
            end
            df << "RUN #{update}apt-get install --yes #{Shellwords.join(deps)}"
          when 'redhat'
            df << "RUN yum -y install #{Shellwords.join(deps)}"
          else
            raise "Unknown flavour: #{variables[:flavour]}"
          end
        end

        df << "ADD .build.sh /tmp/build/"
        df << "ENTRYPOINT /tmp/build/.build.sh"
        df << ''
        return df.join("\n")
      end

      def build_sh
        df = ['#!/bin/bash']
        df << 'set -e'
        recipe.steps.each do |v|
          if v.respond_to? :name
            df << "echo -e '\\e[1;32m====> #{Shellwords.escape v.name}\\e[0m'"
          end
          df << v.to_s
        end
        df << ''
        return df.join("\n")
      end

      def tar_io
        sio = StringIO.new
        tar = Gem::Package::TarWriter.new(sio)
        tar.add_file('.build.sh','0777') do |io|
          io.write(build_sh)
        end
        tar.add_file(NAME,'0777') do |io|
          io.write(dockerfile)
        end
        #tar.close
        sio.rewind
        return sio
      end
    end

  end
end ; end
