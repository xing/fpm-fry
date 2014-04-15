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
        begin
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
        rescue Client::FileNotFound
        end
        begin
          client.read(container,'/etc/redhat-release') do |file|
            if file.header.typeflag == "2" # centos links this file
              client.read(container,File.absolute_path(file.header.linkname,'/etc')) do |file|
                detect_redhat_release(file)
              end
            else
              detect_redhat_release(file)
            end
          end
          return (@distribution and @version)
        rescue Client::FileNotFound
        end
      end

      def detect_redhat_release(file)
        file.read.each_line do |line|
          case(line)
          when /\A(\w+) release ([\d\.]+)/ then
            @distribution = $1.strip.downcase
            @version = $2.strip
          end
        end
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
        if res.status != 201
          raise "#{res.status}: #{res.read_body}"
        end
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
