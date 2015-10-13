module FPM; module Fry
  class JoinedIO
    include Enumerable

    def initialize(*ios)
      @ios = ios
      @pos = 0
      @readbytes = 0
    end

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

    def readpartial( len )
      while (io = @ios[@pos])
        r = io.read( len )
        if r.nil?
          @pos = @pos + 1
          next
        else
          return r
        end
      end
      return nil
    end

    def pos
      @readbytes
    end

    def eof?
      @pos == @ios.size
    end

    def close
      @ios.each(&:close)
    end
  end
end ; end
