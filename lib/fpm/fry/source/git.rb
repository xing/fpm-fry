require 'fileutils'
require 'forwardable'
require 'fpm/fry/exec'
require 'fpm/fry/source'
module FPM; module Fry ; module Source
  # Used to build directly from git.
  #
  # @example in a recipe
  #     source 'https://github.com/ggreer/the_silver_searcher.git'
  # 
  # It automatically recognizes the following url patterns:
  #
  #   - git://…
  #   - git+…://…
  #   - user@host:….git
  #   - https://….git
  #   - https://git.…
  #
  class Git

    REGEX = %r!\A(?:git:|\S+@\S+:\S+\.git\z|https?:(?://git\.|.*\.git\z)|ssh:.*\.git\z|git\+[a-z0-9]+:)!

    # @return :git
    def self.name
      :git
    end

    # Guesses if this url is a git url.
    #
    # @example not a git url
    #   FPM::Fry::Source::Git.guess( "bzr://something" ) #=> nil
    #
    # @example a git url
    #   FPM::Fry::Source::Git.guess( "git://something" ) #=> 4
    #
    # @param [URI,String] url
    # @return [nil] when this uri doesn't match
    # @return [Numeric] number of characters that were used
    def self.guess( url )
      Source::guess_regex(REGEX, url)
    end

    class Cache < Struct.new(:package, :tempdir)
      extend Forwardable

      def_delegators :package, :url, :rev, :logger, :file_map

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
      def initialize(*_)
        super
        update
      end

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
      def repodir
        File.join(tempdir,File.basename(url.path))
      end
    end

    # @return [Cabin::Channel] logger
    attr :logger

    # @return [String] the git binary (default: "git")
    attr :git

    # @return [String] the git rev to pull (default "HEAD")
    attr :rev

    # @return [Hash<String,String>] the file map for generating a docker file
    attr :file_map

    # @return [URI] the uri to pull from
    attr :url

    # @param [URI] url the url to pull from
    # @param [Hash] options
    # @option options [Cabin::Channel] :logger (cabin default channel)
    # @option options [String] :branch git branch to pull
    # @option options [String] :tag git tag to pull
    # @option options [Hash<String,String>] :file_map ({""=>""}) the file map to create the docker file from
    def initialize( url, options = {} )
      url = url.sub(/\A(\S+@\S+):(\S+\.git)\z/,'ssh://\1/\2')
      @url = URI(url)
      @logger = options.fetch(:logger){ Cabin::Channel.get }
      @rev = options[:branch] || options[:tag] || options[:rev] || 'HEAD'
      @file_map = options.fetch(:file_map){ {'' => ''} }
      @git = options[:git] || 'git'
    end

    # @param [String] tempdir
    # @return [Cache]
    def build_cache(tempdir)
      Cache.new(self, tempdir)
    end

  end
end ; end ; end
