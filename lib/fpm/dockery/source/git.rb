require 'fileutils'
require 'forwardable'
require 'open3'
require 'fpm/dockery/source'
module FPM; module Dockery ; module Source
  class Git

    class Cache < Struct.new(:package, :tempdir)
      extend Forwardable

      def_delegators :package, :url, :rev, :logger, :file_map

      def update
        begin
          if !File.exists? repodir
            if git('init', '--bare') != 0
              raise "Initializing git repository failed"
            end
          end
          if git('fetch', url.to_s, rev) != 0
            raise "Failed to fetch from remote #{url.to_s} ( #{rev} )"
          end
          return self
        rescue Errno::ENOENT
          raise "Cannot find git binary. Is it installed?"
        end
      end

      def tar_io
        cmd = [package.git, "--git-dir=#{repodir}",'archive','--format=tar','FETCH_HEAD']
        logger.debug("Running git",cmd: cmd)
        IO.popen(cmd)
      end
    private
      def repodir
        File.join(tempdir,File.basename(url.path))
      end

      def git(*args)
        cmd = [package.git, "--git-dir=#{repodir}",*args]
        logger.debug("Running git",cmd: cmd)
        Open3.popen3(*cmd) do |sin, out, err, thr|
          sin.close
          out.each_line do |line|
            logger.debug(line.chomp)
          end
          err.each_line do |line|
            logger.debug(line.chomp)
          end
          return thr.value
        end
      end

    end

    attr :logger, :git, :rev, :file_map, :url

    def initialize( url, options = {} )
      @url = URI(url)
      @logger = options.fetch(:logger){ Cabin::Channel.get }
      @rev = options[:branch] || options[:tag] || 'HEAD'
      @file_map = options.fetch(:file_map){ {'' => ''} }
      @git = options[:git] || 'git'
    end

    def build_cache(tempdir)
      Cache.new(self, tempdir).update
    end

  end
end ; end ; end
