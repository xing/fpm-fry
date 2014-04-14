module FPM; module Dockery
  class StreamParser

    attr :out, :err

    def initialize(out, err)
      @out, @err = out, err
    end

    def <<(data)
      # simple solution for now
      case(data.ord)
      when 1
        out << data.byteslice(8,data.bytesize)
      when 2
        err << data.byteslice(8,data.bytesize)
      else
        raise ArgumentError, "Bad formated docker stream"
      end
    end

  end
end ; end
