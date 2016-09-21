require 'fileutils'
require 'forwardable'
require 'fpm/fry/exec'
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
            Exec::exec(package.git, "--git-dir=#{repodir}",'init', '--bare', description: "initializing git repository", logger: logger)
          end
          Exec::exec(package.git, "--git-dir=#{repodir}",'fetch','--depth=1', url.to_s, rev, description: 'fetching from remote', logger: logger)
          return self
        rescue => e
          raise CacheFailed.new(e, url: url.to_s, rev: rev)
        end
      end

      def tar_io
        Exec::popen(package.git, "--git-dir=#{repodir}",'archive','--format=tar','FETCH_HEAD', logger: logger)
      end

      def copy_to(dst)
        Exec[
          package.git, "--git-dir=#{repodir}", "--work-tree=#{dst}",'checkout','FETCH_HEAD','--','*',
          chdir: dst, logger: logger
        ]
      end

      def cachekey
        Exec::exec(package.git, "--git-dir=#{repodir}",'rev-parse','FETCH_HEAD^{tree}', logger: logger).chomp
      end
    private
      def repodir
        File.join(tempdir,File.basename(url.path))
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
