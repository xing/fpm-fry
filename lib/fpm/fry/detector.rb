require 'fpm/fry/client'
module FPM; module Fry

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
          return !!(@distribution and @version)
        rescue Client::FileNotFound
        end
        begin
          client.read(container,'/etc/debian_version') do |file|
            content = file.read
            if /\A\d+(?:\.\d+)+\Z/ =~ content
              @distribution = 'debian'
              @version = content.strip
            end
          end
          return !!(@distribution and @version)
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
          return !!(@distribution and @version)
        rescue Client::FileNotFound
        end
        return false
      end

    private
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

    class Image < Struct.new(:client,:image,:factory)
      attr :distribution
      attr :version

      def initialize(client, image, factory = Container)
        super
      end

      def detect!
        body = JSON.generate({"Image" => image, "Cmd" => "exit 0"})
        res = client.post( path: client.url('containers','create'),
                           headers: {'Content-Type' => 'application/json'},
                           body: body,
                           expects: [201]
                         )
        body = JSON.parse(res.body)
        container = body.fetch('Id')
        begin
          d = factory.new(client,container)
          if d.detect!
            @distribution = d.distribution
            @version = d.version
            return true
          else
            return false
          end
        ensure
          client.delete(path: client.url('containers',container))
        end
      end
    end


  end
end ; end
