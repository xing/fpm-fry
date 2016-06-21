require 'json'
module FPM; module Fry
  class BuildOutputParser < Struct.new(:out)

    attr :images

    def initialize(*_)
      super
      @images = []
    end

    def call(chunk, *_)
      # new docker for Mac results in data like this:
      # "{'stream':' ---\\u003e 3bc51d6a4c46\\n'}\r\n{'stream':'Step 2 : WORKDIR /tmp/build\\n'}\r\n"
      # this isn't valid JSON, of course, so we process each part individually
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
