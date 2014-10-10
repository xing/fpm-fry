require 'uri'
require 'digest'
require 'net/http'
require 'forwardable'
require 'zlib'
require 'fpm/dockery/source'
module FPM; module Dockery ; module Source
  class Package

    REGEX = %r!\Ahttps?:!

    def self.guess( url )
      Source::guess_regex(REGEX, url)
    end

    class RedirectError < CacheFailed
    end

    class Cache < Struct.new(:package,:tempdir)
      extend Forwardable

      def_delegators :package, :url, :checksum, :checksum_algorithm, :agent, :extension, :logger, :file_map

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

      def tar_io
        update!
        IO_CLASSES.fetch(extension).open(tempfile)
      end

      def copy_to(dst)
        update!
        cmd = ['tar','-xf',tempfile,'-C',dst]
        logger.debug("Running tar",cmd: cmd)
        system(*cmd)
      end

      def cachekey
        @observed_checksum || checksum
      end

    end

    KNOWN_EXTENSION = ['.tar','.tar.gz', '.tgz'
                       # currently unsupported
                       #,'.tar.bz', '.tar.xz','.tar.lz'
                      ]
    IO_CLASSES = {
      '.tar' => File,
      '.tar.gz' => Zlib::GzipReader,
      '.tgz' => Zlib::GzipReader
    }

    attr :file_map, :data, :url, :extension, :checksum, :checksum_algorithm, :agent, :logger

    def initialize( url, options = {} )
      @url = URI(url)
      @extension = options.fetch(:extension){
        KNOWN_EXTENSION.find{|ext|
          @url.path.end_with?(ext)
        }
      }
      @logger = options.fetch(:logger){ Cabin::Channel.get }
      @checksum = options[:checksum]
      @checksum_algorithm = guess_checksum_algorithm(options[:checksum])
      @file_map = options.fetch(:file_map){ {'' => ''} }
    end

    def build_cache(tempdir)
      Cache.new(self, tempdir)
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
