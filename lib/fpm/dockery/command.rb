require 'tmpdir'
require 'fileutils'
require 'clamp'
require 'json'
require 'forwardable'
require 'fpm/dockery/ui'
require 'fpm/command'

module FPM; module Dockery

  class Command < Clamp::Command

    option '--debug', :flag, 'Turns on debugging'
    option '--[no-]tls', :flag, 'Turns on tls ( default is false for schema unix, tcp and http and true for https )'
    option '--[no-]tlsverify', :flag, 'Turns off tls peer verification', default:true, environment_variable: 'DOCKER_TLS_VERIFY'

    subcommand 'fpm', 'Works like fpm but with docker support', FPM::Command

    def client
      @client ||= begin
        client = FPM::Dockery::Client.new(
          logger: logger,
          tls: tls?, tlsverify: tlsverify?
        )
        logger.info("Docker connected",client.server_version)
        client
      end
    end

    attr_writer :client

    subcommand 'detect', 'Detects distribution from an image, a container or a given name' do

      option '--image', 'image', 'Docker image to detect'
      option '--container', 'container', 'Docker container to detect'
      option '--distribution', 'distribution', 'Distribution name to detect'

      attr :ui
      extend Forwardable
      def_delegators :ui, :logger

      def initialize(*_)
        super
        @ui = UI.new()
        if debug?
          ui.logger.level = :debug
        end
      end

      def execute
        require 'fpm/dockery/os_db'
        require 'fpm/dockery/detector'

        if image
          d = Detector::Image.new(client, image)
        elsif distribution
          d = Detector::String.new(distribution)
        elsif container
          d = Detector::Container.new(client, container)
        else
          logger.error("Please supply either --image, --distribution or --container")
          return 1
        end

        begin
          if d.detect!
            data = {distribution: d.distribution, version: d.version}
            if i = OsDb[d.distribution]
              data[:flavour] = i[:flavour]
            else
              data[:flavour] = "unknown"
            end
            logger.info("Detected distribution",data)
            return 0
          else
            logger.error("Detection failed")
            return 2
          end
        rescue => e
          logger.error(e)
          return 3
        end
      end

    end
  end

end ; end

require 'fpm/dockery/command/cook'
