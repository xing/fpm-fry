require 'json'
module FPM; module Dockery
  class BuildOutputParser < Struct.new(:out)

    attr :images

    def initialize(*_)
      super
      @images = []
    end

    def call(chunk, *_)
      json = JSON.parse(chunk)
      stream = json['stream']
      if /\ASuccessfully built (\w+)\Z/.match(stream)
        images << $1
      end
      out << stream
    end

  end
end ; end
