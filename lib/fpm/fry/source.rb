module FPM; module Fry ; module Source

  class CacheFailed < StandardError

    attr :options

    def initialize(e, opts = {})
      if e.kind_of? Exception
        @options = {reason: e}.merge opts
        super(e.message)
      else
        @options = opts.dup
        super(e.to_s)
      end
    end

    def message
      super + options.inspect
    end

    def to_s
      super + options.inspect
    end
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
