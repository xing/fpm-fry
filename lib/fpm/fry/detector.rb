require 'fpm/fry/client'
module FPM; module Fry

  module Detector

    class String < Struct.new(:value)
      attr :distribution
      attr :version
      attr :codename

      def detect!
        m = /\A([^-]+)-(\d+(?:\.\d+)*)(?: (.+))?/.match(value)
        return false unless m
        @distribution = m[1]
        @version = m[2]
        @codename = m[3]
        return true
      end

    end

    class Container < Struct.new(:client,:container)
      attr :distribution
      attr :version
      attr :codename
      attr :flavour

      def detect!
        begin
          client.read(container,'/usr/bin/apt-get') do |file|
          end
          @flavour = 'debian'
        rescue Client::FileNotFound
        end
        begin
          client.read(container,'/bin/rpm') do |file|
          end
          @flavour = 'redhat'
        rescue Client::FileNotFound
        end
        begin
          client.read_content(container,'/etc/lsb-release').each_line do |line|
            case(line)
            when /\ADISTRIB_ID=/ then
              @distribution = $'.strip.downcase
            when /\ADISTRIB_RELEASE=/ then
              @version = $'.strip
            when /\ADISTRIB_CODENAME=/ then
              @codename = $'.strip
            end
          end
        rescue Client::FileNotFound
        end
        begin
          client.read_content(container,'/etc/os-release').each_line do |line|
            case(line)
            when /\AVERSION=\"(\w+) \((\w+)\)\"/ then
              @version ||= $1
              @codename ||= $2
            end
          end
        rescue Client::FileNotFound
        end
        begin
          content = client.read_content(container,'/etc/debian_version')
          if /\A\d+(?:\.\d+)+\Z/ =~ content
            @distribution = 'debian'
            @version = content.strip
          end
        rescue Client::FileNotFound
        end
        begin
          detect_redhat_release(client.read_content(container,'/etc/redhat-release'))
        rescue Client::FileNotFound
        end
        return !!(@flavour and @distribution and @version)
      end

    private
      def detect_redhat_release(content)
        content.each_line do |line|
          case(line)
          when /\A(\w+)(?: Linux)? release ([\d\.]+)/ then
            @distribution = $1.strip.downcase
            @version = $2.strip
          end
        end
      end
    end

    class Image < Struct.new(:client,:image,:factory)

      class ImageNotFound < StandardError
      end

      attr :distribution
      attr :version
      attr :codename
      attr :flavour

      def initialize(client, image, factory = Container)
        super
      end

      def detect!
        body = JSON.generate({"Image" => image, "Cmd" => "exit 0"})
        begin
          res = client.post( path: client.url('containers','create'),
                             headers: {'Content-Type' => 'application/json'},
                             body: body,
                             expects: [201]
                           )
        rescue Excon::Errors::NotFound
          raise ImageNotFound, "Image #{image.inspect} not found. Did you do a `docker pull #{image}` before?"
        end
        body = JSON.parse(res.body)
        container = body.fetch('Id')
        begin
          d = factory.new(client,container)
          if d.detect!
            @distribution = d.distribution
            @version = d.version
            @codename = d.codename
            @flavour = d.flavour
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
