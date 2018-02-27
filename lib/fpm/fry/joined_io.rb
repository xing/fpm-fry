module FPM; module Fry
  # Joins together multiple IOs
  class JoinedIO
    include Enumerable

    # @param [IO] ios
    def initialize(*ios)
      @ios = ios
      @pos = 0
      @readbytes = 0
    end

    # Reads length bytes or all if length is nil.
    # @param [Numeric, nil] len
    # @return [String] resulting bytes
    def read( len = nil )
      buf = []
      if len.nil?
        while chunk = readpartial(512)
          buf << chunk
          @readbytes += chunk.bytesize
        end
        return buf.join
      else
        con = 0
        while con < len
          chunk = readpartial(len - con)
          if chunk.nil?
            if con == 0
              return nil
            else
              return buf.join
            end
          end
          @readbytes += chunk.bytesize
          con += chunk.bytesize
          buf << chunk
        end
        return buf.join
      end
    end

    # Reads up to length bytes.
    # @param [Numeric] length
    # @return [String] chunk
    # @return [nil] at eof
    def readpartial( length )
      while (io = @ios[@pos])
        r = io.read( length )
        if r.nil?
          @pos = @pos + 1
          next
        else
          if io.eof?
            @pos = @pos + 1
          end
          return r
        end
      end
      return nil
    end

    # @return [Numeric] number bytes read
    def pos
      @readbytes
    end

    # @return [true,false] 
    def eof?
      @pos == @ios.size
    end

    # Closes all IOs.
    def close
      @ios.each(&:close)
    end
  end
end ; end
