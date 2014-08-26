require 'fiber'
require 'shellwords'
require 'rubygems/package'
require 'fpm/dockery/os_db'
require 'fpm/dockery/source'
require 'fpm/dockery/joined_io'
module FPM; module Dockery
  class DockerFile < Struct.new(:variables,:cache,:recipe)

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
        tar.add_file('Dockerfile','0777') do |io|
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

      def initialize(base, variables, recipe)
        variables = variables.dup
        if variables[:distribution] && !variables[:flavour] && OsDb[variables[:distribution]]
          variables[:flavour] = OsDb[variables[:distribution]][:flavour]
        end
        variables.freeze
        super(base, variables, recipe)
      end

      def dockerfile
        df = []
        df << "FROM #{base}"
        df << "WORKDIR /tmp/build"

        deps = (recipe.build_depends.merge recipe.depends).select{|_,v| v.fetch(:install,true) }.map{|k,_| k }.sort
        if deps.any?
          case(variables[:flavour])
          when 'debian'
            df << "RUN apt-get install --yes #{Shellwords.join(deps)}"
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
        recipe.steps.each do |k,v|
          df << "echo -e '\\e[1;32m====> #{Shellwords.escape k}\\e[0m'"
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
        tar.add_file('Dockerfile','0777') do |io|
          io.write(dockerfile)
        end
        #tar.close
        sio.rewind
        return sio
      end
    end

  end
end ; end
