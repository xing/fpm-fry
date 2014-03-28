require 'fpm/dockery/client'
module FPM; module Dockery

  module Detector

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
        req = client.request('containers','create')
        req.method = 'POST'
        req.body = JSON.generate({"Image" => image, "Cmd" => "exit 0"})
        req.headers.set('Content-Type','application/json')
        req.headers.set('Content-Length',req.body.bytesize)
        res = client.agent.execute(req)
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
          req = client.request('containers',container)
          req.method = 'DELETE'
          client.agent.execute(req)
        end
      end
    end
  end
end ; end
