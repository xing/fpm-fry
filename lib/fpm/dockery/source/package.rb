require 'uri'
require 'digest'
require 'ftw'
module FPM; module Dockery ; module Source
  class Package

    KNOWN_EXTENSION = ['.tar','.tar.gz', '.tgz','.tar.bz', '.tar.xz','.tar.lz']

    attr :tempdir, :data, :url, :extension, :checksum, :agent, :logger

    def initialize( tempdir, data, options = {} )
      @tempdir = tempdir
      @data = data
      @url = URI(@data['url'])
      @extension = @data['extension'] || KNOWN_EXTENSION.first{|ext|
        @url.path.end_with?(ext)
      }
      @agent = options.fetch(:agent, FTW::Agent.new)
      @logger = options.fetch(:logger, Cabin::Channel.get)
      @checksum = @data['checksum']
      @observed_checksum = nil
    end

    def cache_valid?
      c = @observed_checksum || checksum
      begin
        check_checksum( Digest::SHA256.file(tempfile) , c )
      rescue Errno::ENOENT
        return false
      end
    end

    def update_cache

      d = Digest::SHA256.new
      resp = agent.get!(url)
      if resp.status == 200
        f = File.new(tempfile,'w')
        begin
          resp.read_body do | chunk |
            d.update(chunk)
            f.write(chunk)
          end
        ensure
          f.close
        end
      else
        logger.error('update cache failed',http_status: resp.status)
        return false
      end

      @observed_checksum = d.hexdigest
      if checksum
        return check_checksum(d)
      else
        return true
      end
    end

    def tempfile
      File.join(tempdir,File.basename(url.path))
    end

    def check_checksum( digest , c = checksum)
      logger.info('comparing checksum', given: digest.hexdigest, expected: c)
      digest.hexdigest == c
    end

  end
end end end
