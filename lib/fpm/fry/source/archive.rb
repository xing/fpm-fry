require 'uri'
require 'digest'
require 'net/http'
require 'forwardable'
require 'zlib'
require 'fpm/fry/source'
require 'fpm/fry/exec'
require 'cabin'
module FPM; module Fry ; module Source
  # Used to build from an archive.
  #
  # @example in a recipe
  #   source 'http://curl.haxx.se/download/curl-7.36.0.tar.gz',
  #     checksum: '33015795d5650a2bfdd9a4a28ce4317cef944722a5cfca0d1563db8479840e90'
  #
  # It is highly advised to supply a checksum ( althought it's not mandatory ). 
  # This checksum will be used to test for cache validity and data integrity. The 
  # checksum algorithm is automatically guessed based on the length of the checksum.
  #
  #   - 40 characters = sha1
  #   - 64 characters = sha256
  # 
  # Let's be honest: all other checksum algorithms aren't or shouldn't be in use anyway.
  class Archive

    REGEX = %r!\Ahttps?:!

    # @return [:archive]
    def self.name
      :package
    end

    def self.aliases
      [:package,:http]
    end

    # Guesses if the given url is an archive.
    # 
    # @example not an archive
    #   FPM::Fry::Source::Archive.guess("bzr://something") # => nil
    #
    # @example an archive
    #   FPM::Fry::Source::Archive.guess("https://some/thing.tar.gz") #=> 6
    #
    # @return [nil] when it's not an archive
    # @return [Numeric] number of characters used
    def self.guess( url )
      Source::guess_regex(REGEX, url)
    end

    # Raised when too many redirects happened.
    class RedirectError < CacheFailed
    end

    # Raised when the archive type is not known.
    class UnknownArchiveType < StandardError
      include WithData
    end

    class Cache < Struct.new(:package,:tempdir)
      extend Forwardable

      def_delegators :package, :url, :checksum, :checksum_algorithm, :logger, :file_map, :to

      # @return [String] cachekey which is equal to the checksum
      def cachekey
        @observed_checksum || checksum
      end

    private

      def initialize(*_)
        super
        if !checksum
          update!
        end
      end

      def cache_valid?
        c = @observed_checksum || checksum
        begin
          checksum_algorithm.file(tempfile).hexdigest == c
        rescue Errno::ENOENT
          return false
        end
      end

      def update!
        if cache_valid?
          logger.debug("Found valid cache", url: url, tempfile: tempfile)
          return
        end
        d = checksum_algorithm.new
        f = nil
        actual_url = url.to_s
        fetch_url(url) do | last_url, resp|
          actual_url = last_url.to_s
          begin
            f = File.new(tempfile,'w')
            resp.read_body do | chunk |
              d.update(chunk)
              f.write(chunk)
            end
          rescue => e
            raise CacheFailed, e
          ensure
            f.close
          end
        end

        @observed_checksum = d.hexdigest
        logger.debug("Got checksum", checksum: @observed_checksum, url: actual_url)
        if checksum
          if d.hexdigest != checksum
            raise CacheFailed.new("Checksum failed",given: d.hexdigest, expected: checksum, url: actual_url)
          end
        else
          return true
        end
      end

      def fetch_url( url, redirs = 3, &block)
        url = URI(url.to_s) unless url.kind_of? URI
        Net::HTTP.get_response(url) do |resp|
          case(resp)
          when Net::HTTPRedirection
            if redirs == 0
              raise RedirectError.new("Too many redirects", url: url.to_s, location: resp['location'])
            end
            logger.debug("Following redirect", url: url.to_s , location: resp['location'])
            return fetch_url( resp['location'], redirs - 1, &block)
          when Net::HTTPSuccess
            return block.call( url, resp)
          else
            raise CacheFailed.new('Unable to fetch file',url: url.to_s, http_code: resp.code.to_i, http_message: resp.message)
          end
        end
      end

      def tempfile
        File.join(tempdir,File.basename(url.path))
      end

    end

    class TarCache < Cache

      def tar_io
        update!
        ioclass.open(tempfile)
      end

      def copy_to(dst)
        update!
        Exec['tar','-xf',tempfile,'-C',dst, logger: logger]
      end

      def prefix
        update!
        @prefix ||= prefix!
      end

      def prefix!
        longest = nil
        Exec.popen('tar','-tf',tempfile, logger: logger).each_line.map do |line|
          line = line.chomp
          parts = line.split('/')
          parts.pop unless line[-1] == '/'
          if longest.nil?
            longest = parts
          else
            longest.each_with_index do | e, i |
              if parts[i] != e
                longest = longest[0...i]
                break
              end
            end
            break if longest.none?
          end
        end
        return Array(longest).join('/')
      end

    protected
      def ioclass
        File
      end
    end

    class TarGzCache < TarCache
    protected

      def ioclass
        Zlib::GzipReader
      end
    end

    class TarBz2Cache < TarCache

      def tar_io
        update!
        return Exec::popen('bzcat', tempfile, logger: logger)
      end

    end

    class ZipCache < Cache

      def tar_io
        unpack!
        return Exec::popen('tar','-c','.', chdir: unpacked_tmpdir)
      end

      def copy_to(dst)
        update!
        Exec['unzip', tempfile, '-d', dst ]
      end

      def prefix
        unpack!
        Source::prefix(unpacked_tmpdir)
      end
    private

      def unpack!
        if !::File.directory?( unpacked_tmpdir )
          workdir = unpacked_tmpdir + '.tmp'
          begin
            FileUtils.mkdir(workdir)
          rescue Errno::EEXIST
            FileUtils.rm_rf(workdir)
            FileUtils.mkdir(workdir)
          end
          copy_to( workdir )
          File.rename(workdir, unpacked_tmpdir)
        end
      end

      def unpacked_tmpdir
        File.join(tempdir, cachekey)
      end
    end

    class PlainCache < Cache

      def tar_io
        update!
        dir = File.dirname(tempfile)
        Exec::popen('tar','-c',::File.basename(tempfile), logger: logger, chdir: dir)
      end

      def copy_to(dst)
        update!
        FileUtils.cp( tempfile, dst )
      end

      def prefix
        ""
      end

    end

    CACHE_CLASSES = {
      '.tar' => TarCache,
      '.tar.gz' => TarGzCache,
      '.tgz' => TarGzCache,
      '.tar.bz2' => TarBz2Cache,
      '.zip' => ZipCache,
      '.bin' => PlainCache,
      '.bundle' => PlainCache
    }

    attr :file_map, :data, :url, :checksum, :checksum_algorithm, :logger, :to

    # @param [URI] url
    # @param [Hash] options
    # @option options [Cabin::Channel] :logger (default cabin channel)
    # @option options [String] :checksum a checksum of the archive
    # @raise [UnknownArchiveType] when the archive type is unknown
    def initialize( url, options = {} )
      @url = URI(url)
      @cache_class = guess_cache_class(@url)
      @logger = options.fetch(:logger){ Cabin::Channel.get }
      @checksum = options[:checksum]
      @checksum_algorithm = guess_checksum_algorithm(options[:checksum])
      @file_map = options[:file_map]
      @to = options[:to]
    end

    # Creates a cache.
    #
    # @param [String] tempdir
    # @return [TarCache] for plain .tar files
    # @return [TarGzCache] for .tar.gz files
    # @return [TarBz2Cache] for .tar.bz2 files
    # @return [ZipCache] for .zip files
    # @return [PlainCache] for .bin files
    def build_cache(tempdir)
      @cache_class.new(self, tempdir)
    end
  private

    def guess_cache_class( url )
      CACHE_CLASSES.each do |ext,klass|
        if url.path.end_with?(ext)
          return klass
        end
      end
      raise UnknownArchiveType.new("Unknown archive type", url: url.to_s, known_extensions: CACHE_CLASSES.keys)
    end

    def guess_checksum_algorithm( checksum )
      case(checksum)
      when nil
        return Digest::SHA256
      when /\A(sha256:)?[0-9a-f]{64}\z/ then
        return Digest::SHA256
      when /\A(sha1:)?[0-9a-f]{40}\z/ then
        return Digest::SHA1
      else
        raise "Unknown checksum algorithm"
      end
    end

  end
end end end
