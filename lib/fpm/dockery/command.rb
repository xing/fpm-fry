require 'clamp'
module FPM; module Dockery

  class Command < Clamp::Command

    subcommand 'fpm', 'Works like fpm but with docker support', FPM::Command

    subcommand 'detect', 'Detects distribution from iamge' do

      option '--image', 'image', 'Docker image to detect'
      option '--container', 'container', 'Docker container to detect'

      attr :logger

      def initialize(*_)
        super
        @logger = Cabin::Channel.get
        @logger.subscribe(STDOUT)
        @logger.level = :debug
      end

      def execute
        require 'fpm/dockery/detector'
        client = FPM::Dockery::Client.new(logger: logger)
        if image
          d = Detector::Image.new(client, image)
        else
          d = Detector::Container.new(client, container)
        end

        if d.detect!
          puts "Found #{d.distribution}/#{d.version}"
        else
          puts "Failed"
        end
      end

    end

    subcommand 'cook', 'Cooks a package' do

#      option '--distribution', 'distribution', 'Distribution like ubuntu-12.04', default: 'ubuntu-12.04'

      parameter 'image', 'Docker image to build from'
      parameter '[recipe]', 'Recipe file to cook', default: 'recipe.rb'

      attr :logger

      def initialize(*_)
        super
        @logger = Cabin::Channel.get
        @logger.subscribe(STDOUT)
        @logger.level = :debug
      end

      def execute
        require 'fpm/dockery/recipe'
        require 'fpm/dockery/detector'
        client = FPM::Dockery::Client.new(logger: logger)
        d = Detector::Image.new(client, image)
        unless d.detect!
          logger.error("Unable to detect distribution from given image")
          return 101
        end
        begin
          r = FPM::Dockery::Recipe.from_file( recipe )
        rescue Errno::ENOENT
          logger.error("Recipe not found")
          return 1
        end
        return 0
      end

    end


  end

end ; end
