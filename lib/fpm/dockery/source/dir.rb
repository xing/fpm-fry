require 'fpm/dockery/source'
require 'fileutils'
require 'digest'
module FPM; module Dockery ; module Source
  class Dir

    REGEX = %r!\A(?:file:|/|\./)!

    def self.guess( url )
      Source::guess_regex(REGEX, url)
    end

    class Cache < Struct.new(:package, :dir)
      extend Forwardable

      def_delegators :package, :url, :logger, :file_map

      def tar_io
        cmd = ['tar','-c','.']
        logger.debug("Running tar",cmd: cmd, dir: dir)
        ::Dir.chdir(dir) do
          return IO.popen(cmd)
        end
      end

      def copy_to(dst)
        children = ::Dir.new(dir).select{|x| x[0...1] != "." }.map{|x| File.join(dir,x) }
        FileUtils.cp_r(children, dst)
      end

      def cachekey
        dig = Digest::SHA2.new
        tar_io.each(1024) do |block|
          dig << block
        end
        return dig.hexdigest
      end
    end

    attr :url, :logger, :file_map

    def initialize( url, options = {} )
      @url = URI(url)
      @logger = options.fetch(:logger){ Cabin::Channel.get }
      @file_map = options.fetch(:file_map){ {'' => ''} }
    end

    def build_cache(_)
      Cache.new(self, url.path)
    end
  end
end ; end ; end

