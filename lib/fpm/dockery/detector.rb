require 'fpm/dockery/client'
module FPM; module Dockery

  module Detector

    class String < Struct.new(:value)
      attr :distribution
      attr :version

      def detect!
        @distribution, @version = value.split('-',2)
        return true
      end

    end

    class Container < Struct.new(:client,:container)
      attr :distribution
      attr :version

      def detect!
        client.read(container,'/etc/lsb-release') do |file|
          file.read.each_line do |line|
            case(line)
            when /\ADISTRIB_ID=/ then
              @distribution = $'.strip.downcase
            when /\ADISTRIB_RELEASE=/ then
              @version = $'.strip
            end
          end
        end
        return (@distribution and @version)
      end
    end

    class Image < Struct.new(:client,:image)
      attr :distribution
      attr :version

      def detect!
        res = client.request('containers','create') do |req|
          req.method = 'POST'
          req.body = JSON.generate({"Image" => image, "Cmd" => "exit 0"})
          req.headers.set('Content-Type','application/json')
          req.headers.set('Content-Length',req.body.bytesize)
        end
        raise res.status.to_s if res.status != 201
        body = JSON.parse(res.read_body)
        container = body['Id']
        begin
          d = Container.new(client,container)
          if d.detect!
            @distribution = d.distribution
            @version = d.version
            return true
          else
            return false
          end
        ensure
          client.request('containers',container) do |req|
            req.method = 'DELETE'
          end
        end
      end
    end


  end
end ; end
