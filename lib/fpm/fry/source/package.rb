require 'uri'
require 'digest'
require 'net/http'
require 'forwardable'
require 'zlib'
require 'fpm/fry/source'
require 'cabin'
require 'cabin/channel'

module FPM; module Fry ; module Source
  class Package

    REGEX = %r!\Ahttps?:!

    def self.name
      :package
    end

    def self.aliases
      [:http]
    end

    def self.guess( url )
      Source::guess_regex(REGEX, url)
    end

    class RedirectError < CacheFailed
    end

    class Cache < Struct.new(:package,:tempdir)
      extend Forwardable

      def_delegators :package, :url, :checksum, :checksum_algorithm, :agent, :logger, :file_map

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
        fetch_url(url) do |resp|
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
        logger.debug("got checksum", checksum: @observed_checksum)
        if checksum
          if d.hexdigest != checksum
            raise CacheFailed.new("Checksum failed",given: d.hexdigest, expected: checksum)
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
              raise RedirectError, "Too many redirects"
            end
            logger.debug("Following redirect", url: url.to_s , location: resp['location'])
            return fetch_url( resp['location'], redirs - 1, &block)
          when Net::HTTPSuccess
            return block.call(resp)
          else
            raise CacheFailed.new('Unable to fetch file',url: url.to_s, http_code: resp.code, http_message: resp.message)
          end
        end
      end

      def tempfile
        File.join(tempdir,File.basename(url.path))
      end

      def cachekey
        @observed_checksum || checksum
      end

    end

    class TarCache < Cache

      def tar_io
        update!
        ioclass.open(tempfile)
      end

      def copy_to(dst)
        update!
        cmd = ['tar','-xf',tempfile,'-C',dst]
        logger.debug("Running tar",cmd: cmd)
        system(*cmd)
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
        cmd = ['bzcat',tempfile]
        logger.debug("Running bzcat",cmd: cmd)
        return IO.popen(cmd)
      end

    end

    class ZipCache < Cache

      def tar_io
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
        cmd = ['tar','-c','.']
        logger.debug("Running tar",cmd: cmd, dir: unpacked_tmpdir)
        ::Dir.chdir(unpacked_tmpdir) do
          return IO.popen(cmd)
        end
      end

      def copy_to(dst)
        update!
        cmd = ['unzip', tempfile, '-d', dst ]
        logger.debug("Running unzip",cmd: cmd)
        system(*cmd, out: '/dev/null')
      end

      def unpacked_tmpdir
        File.join(tempdir, cachekey)
      end
    end

    class PlainCache < Cache

      def tar_io
        update!
        cmd = ['tar','-c',::File.basename(tempfile)]
        dir = File.dirname(tempfile)
        logger.debug("Running tar",cmd: cmd, dir: dir)
        ::Dir.chdir(dir) do
          return IO.popen(cmd)
        end
      end

      def copy_to(dst)
        update!
        FileUtils.cp( tempfile, dst )
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

    attr :file_map, :data, :url, :extension, :checksum, :checksum_algorithm, :agent, :logger

    def initialize( url, options = {} )
      @url = URI(url)
      @extension = options.fetch(:extension){
        CACHE_CLASSES.keys.find{|ext|
          @url.path.end_with?(ext)
        }
      }
      @logger = options.fetch(:logger){ Cabin::Channel.get }
      @checksum = options[:checksum]
      @checksum_algorithm = guess_checksum_algorithm(options[:checksum])
      @file_map = options.fetch(:file_map){ {'' => ''} }
    end

    def build_cache(tempdir)
      CACHE_CLASSES.fetch(extension).new(self, tempdir)
    end
  private

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
