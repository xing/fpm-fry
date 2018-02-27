require 'fpm/fry/with_data'
module FPM; module Fry ; module Source

  # Raised when building a cache failed.
  class CacheFailed < StandardError
    include WithData
  end

  # A special source that is empty.
  module Null

    # A special cache that is empty.
    module Cache

      # @return [IO] an empty tar
      def self.tar_io
        StringIO.new("\x00"*1024)
      end

      # @return [Hash] an empty hash
      def self.file_map
        return {}
      end

      # @return [String] 32 times zero
      def self.cachekey
        return '0' * 32
      end

      # @return [String] common path prefix of all files that should be stripped
      def self.prefix
        return ""
      end
    end

    # @see FPM::Fry::Source::Null::Cache
    # @return {FPM::Fry::Source::Null::Cache}
    def self.build_cache(*_)
      return Cache
    end

  end

  class << self

    # @api private
    def guess_regex(rx, url)
      if m = rx.match(url.to_s)
        return m[0].size
      end
    end

    # @api private
    # @param dir [String] directory
    # @return [String] prefix
    def prefix(dir)
      e = ::Dir.entries(dir)
      if e.size != 3
        return ""
      end
      other = (e - ['.','..']).first
      path = File.join(dir, other)
      if File.directory?( path )
        pf = prefix(path)
        if pf == ""
          return other
        else
          return File.join(other, pf)
        end
      else
        return ""
      end
    end

  end
end ; end ; end
