require 'json'
module FPM; module Fry
  class BuildOutputParser < Struct.new(:out)

    attr :images

    def initialize(*_)
      super
      @images = []
    end

    def call(chunk, *_)
      chunk.split("\r\n").each do |sub_chunk|
        json = JSON.parse(sub_chunk)
        stream = json['stream']
        if /\ASuccessfully built (\w+)\Z/.match(stream)
          images << $1
        end
        out << stream
      end
    end

  end
end ; end
