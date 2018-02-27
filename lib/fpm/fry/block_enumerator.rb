module FPM; module Fry
  # Helper class that reads an IO in chunks.
  #
  # @api private
  class BlockEnumerator < Struct.new(:io, :blocksize)
    include Enumerable

    # @param [IO] io
    # @param [Numeric] blocksize
    def initialize(io, blocksize = 128)
      super
    end

    # @return [Enumerator] unless called with a block
    # @yield [chunk] One chunk from the io
    # @yieldparam chunk [String]
    def each
      return to_enum unless block_given?
      # Reading bigger chunks is far more efficient than invoking #each on an IO.
      while chunk = io.read(blocksize)
        yield chunk
      end
      return nil
    end

    # @return [String] chunk or empty string at EOF
    def call
      while x = io.read(blocksize)
        next if x == ""
        return x
      end
      return ""
   end
  end
end ; end
