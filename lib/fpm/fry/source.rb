require 'fpm/fry/with_data'
module FPM; module Fry ; module Source

  class CacheFailed < StandardError
    include WithData
  end

  module Null

    module Cache
      def self.tar_io
        StringIO.new("\x00"*1024)
      end
      def self.file_map
        return {}
      end
      def self.cachekey
        return '0' * 32
      end
    end

    def self.build_cache(*_)
      return Cache
    end

  end

  class << self

    def guess_regex(rx, url)
      if m = rx.match(url.to_s)
        return m[0].size
      end
    end

  end
end ; end ; end
