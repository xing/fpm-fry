require 'fpm/fry/with_data'
module FPM; module Fry ; 
  
  # h2. Interface
  module Source

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

  end
end ; end ; end
