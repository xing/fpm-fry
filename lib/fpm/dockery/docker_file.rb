require 'fiber'
require 'rubygems/package'
module FPM; module Dockery
  class DockerFile < Struct.new(:variables,:cache,:recipe)

    class FiberIO
      def initialize()
        @buf = nil
      end
      def write( x )
        raise "Buffer already set with #{@buf.inspect}" if @buf
        @buf = [Fiber.current, x]
        Fiber.yield
      end
      def each
        while !@buf.nil?
          fiber, x = @buf
          @buf = nil
          yield x
          if fiber.alive?
            fiber.resume
          end
        end
      end
    end

    class JoinedIO
      #FINAL = ("\0" * 1024).freeze

      def initialize(*ios)
        @ios = ios
      end

      def each
        while io = @ios.shift
          puts io.inspect
          begin
            io.each do |chunk|
              #if chunk.end_with? FINAL
              #  yield chunk[0..-1025]
              #  puts "Found final"
              #end
              yield chunk
            end
          ensure
            io.close
          end
        end
      end

      def close
        while io = @ios.shift
          io.close
        end
      end
    end

    def dockerfile
      df = []
      df << "FROM #{variables[:image]}"

      df << "RUN mkdir /tmp/build"

      # if flavor == deb
      deps = recipe.depends.select{|_,v| v.fetch(:install,true) }.map{|k,_| k }
      if deps.any?
        df << "RUN apt-get install --yes #{deps.join(' ')}"
      end
      # end

      cache.file_map.each do |from, to|
        df << "ADD #{from} #{map_dir(to)}"
      end

      df << "ADD .build.sh /tmp/build/"
      df << "WORKDIR /tmp/build"
      df << "ENTRYPOINT /tmp/build/.build.sh"
      return df.join("\n")
    end

    def build_sh
      df = ['#!/bin/bash -e']
      recipe.steps.each do |k,v|
        df << "echo ------> #{k}"
        df << v.to_s
      end
      return df.join("\n")
    end

    def tar_io
      JoinedIO.new(
        self_tar,
        cache.tar_io
      )
    end

    def map_dir(dir)
      if ['','.'].include? dir
        return '/tmp/build'
      else
        return File.join('/tmp/build',dir)
      end
    end

    def self_tar
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
end ; end
