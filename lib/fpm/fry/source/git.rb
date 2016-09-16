require 'fileutils'
require 'forwardable'
require 'open3'
require 'fpm/fry/source'
module FPM; module Fry ; module Source
  class Git

    REGEX = %r!\A(?:git:|\S+@\S+:\S+\.git\z|https?:(?://git\.|.*\.git\z)|ssh:.*\.git\z|git\+[a-z0-9]+:)!

    def self.name
      :git
    end

    def self.guess( url )
      Source::guess_regex(REGEX, url)
    end

    class Cache < Struct.new(:package, :tempdir)
      extend Forwardable

      def_delegators :package, :url, :rev, :logger, :file_map

      def update
        begin
          if !File.exists? repodir
            if (ecode = git('init', '--bare')) != 0
              raise CacheFailed.new("Initializing git repository failed", exit_code: ecode)
            end
          end
          if (ecode = git('fetch','--depth=1', url.to_s, rev)) != 0
            raise CacheFailed.new("Failed to fetch from remote", exit_code: ecode, url: url.to_s, rev: rev)
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

      def copy_to(dst)
        cmd = [package.git, "--git-dir=#{repodir}", "--work-tree=#{dst}",'checkout','FETCH_HEAD','--','*']
        logger.debug("Running git",cmd: cmd)
        system(*cmd, chdir: dst)
      end

      def cachekey
        cmd = [package.git, "--git-dir=#{repodir}",'rev-parse','FETCH_HEAD^{tree}']
        logger.debug("Running git",cmd: cmd)
        return IO.popen(cmd).read.chomp
      end
    private
      def repodir
        File.join(tempdir,File.basename(url.path))
      end

      def git(*args)
        cmd = [package.git, "--git-dir=#{repodir}",*args]
        logger.debug("Running git",cmd: cmd.join(' '))
        Open3.popen3(*cmd) do |sin, out, err, thr|
          sin.close
          out.each_line do |line|
            logger.debug(line.chomp)
          end
          err.each_line do |line|
            logger.debug(line.chomp)
          end
          return thr.value.exitstatus
        end
      end

    end

    attr :logger, :git, :rev, :file_map, :url

    def initialize( url, options = {} )
      url = url.sub(/\A(\S+@\S+):(\S+\.git)\z/,'ssh://\1/\2')
      @url = URI(url)
      @logger = options.fetch(:logger){ Cabin::Channel.get }
      @rev = options[:branch] || options[:tag] || options[:rev] || 'HEAD'
      @file_map = options.fetch(:file_map){ {'' => ''} }
      @git = options[:git] || 'git'
    end

    def build_cache(tempdir)
      Cache.new(self, tempdir).update
    end

  end
end ; end ; end
