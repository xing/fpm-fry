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
        IO.popen(cmd, chdir: dir)
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

