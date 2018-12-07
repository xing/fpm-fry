require 'tmpdir'
require 'fileutils'
require 'clamp'
require 'json'
require 'forwardable'
require 'fpm/fry/ui'
require 'fpm/command'

module FPM; module Fry

  class Command < Clamp::Command

    option '--debug', :flag, 'Turns on debugging'
    option '--[no-]tls', :flag, 'Turns on tls ( default is false for schema unix, tcp and http and true for https )'
    option '--[no-]tlsverify', :flag, 'Turns off tls peer verification', default:true, environment_variable: 'DOCKER_TLS_VERIFY'
    option ["-t", "--tmpdir"], "PATH", 'Write tmp data to PATH', default: '/tmp/fpm-fry', attribute_name: :dir do |s|
      String(s)
    end

    subcommand 'fpm', 'Works like fpm but with docker support', FPM::Command

    attr :ui
    extend Forwardable
    def_delegators :ui, :out, :err, :logger, :tmpdir

    def initialize(invocation_path, ctx = {}, parent_attribute_values = {})
      super
      @ui = ctx.fetch(:ui){ UI.new(tmpdir: dir) }
      @client = ctx[:client]
    end

    def parse(attrs)
      super
      if debug?
        ui.logger.level = :debug
      end
    end

    def client
      @client ||= begin
        client = FPM::Fry::Client.new(
          logger: logger,
          tls: tls?, tlsverify: tlsverify?
        )
        logger.debug("Docker connected",client.server_version)
        client
      end
    end

    attr_writer :client

    subcommand 'detect', 'Detects distribution from an image' do

      parameter 'image', 'Docker image to detect'

      attr :ui
      extend Forwardable
      def_delegators :ui, :logger

      def execute
        require 'fpm/fry/inspector'
        require 'fpm/fry/detector'

        Inspector.for_image(client, image) do | inspector |
          begin
            data = Detector.detect(inspector)
            logger.info("Detected the following parameters",data)
            return 0
          rescue => e
            logger.error(e)
            return 1
          end
        end
      end

    end
  end

end ; end

require 'fpm/fry/command/cook'
