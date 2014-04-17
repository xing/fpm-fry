require 'uri'
require 'digest'
require 'net/http'
require 'forwardable'
require 'zlib'
module FPM; module Dockery ; module Source
  class Package

    class Cache < Struct.new(:package,:tempdir)
      extend Forwardable

      def_delegators :package, :url, :checksum, :agent, :extension, :logger, :file_map

      def update
        if cache_valid?
          logger.debug("Found valid cache", url: url, tempfile: tempfile)
        else
          update!
        end
      end

      def cache_valid?
        c = @observed_checksum || checksum
        begin
          check_checksum( Digest::SHA256.file(tempfile) , c )
        rescue Errno::ENOENT
          return false
        end
      end

      def update!
        d = Digest::SHA256.new
        f = nil
        fetch_url(url) do |resp|
          begin
            f = File.new(tempfile,'w')
            resp.read_body do | chunk |
              d.update(chunk)
              f.write(chunk)
            end
          rescue => e
            logger.error('fetching source failed', reason: e)
            return false
          ensure
            f.close
          end
        end

        @observed_checksum = d.hexdigest
        logger.debug("got checksum", checksum: @observed_checksum)
        if checksum
          return check_checksum(d)
        else
          return true
        end
      end

      def fetch_url( url, redirs = 3, &block)
        url = URI(url.to_s) unless url.kind_of? URI
        Net::HTTP.get_response(url) do |resp|
          case(resp)
          when Net::HTTPRedirection
            return fetch_url( resp['location'], redirs - 1, &block)
          when Net::HTTPSuccess
            return block.call(resp)
          else
            raise resp.message
          end
        end
      end

      def check_checksum( digest , c = checksum)
        logger.info('comparing checksum', given: digest.hexdigest, expected: c)
        digest.hexdigest == c
      end

      def tempfile
        File.join(tempdir,File.basename(url.path))
      end

      def tar_io
        IO_CLASSES.fetch(extension).open(tempfile)
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

    attr :file_map, :data, :url, :extension, :checksum, :agent, :logger

    def initialize( url, options = {} )
      @url = URI(url)
      @extension = options.fetch(:extension){
        KNOWN_EXTENSION.find{|ext|
          @url.path.end_with?(ext)
        }
      }
      @logger = options.fetch(:logger){ Cabin::Channel.get }
      @checksum = options[:checksum]
      @file_map = options.fetch(:file_map){ {'' => ''} }
    end

    def build_cache(tempdir)
      c = Cache.new(self, tempdir)
      c.update
      c
    end
  end
end end end
