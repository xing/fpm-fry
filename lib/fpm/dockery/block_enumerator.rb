module FPM; module Dockery
  class BlockEnumerator < Struct.new(:io, :blocksize)
    include Enumerable

    def initialize(_, blocksize = 128)
      super
    end

    def each
      return to_enum unless block_given?
      # Reading bigger chunks is far more efficient that eaching over the
      while chunk = io.read(blocksize)
        yield chunk
      end
    end

    def call
      while x = io.read(blocksize)
        next if x == ""
        return x
      end
      return ""
    end
  end
end ; end
