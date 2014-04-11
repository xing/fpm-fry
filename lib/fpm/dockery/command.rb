require 'tmpdir'
require 'fileutils'
require 'clamp'
module FPM; module Dockery

  class Command < Clamp::Command

    subcommand 'fpm', 'Works like fpm but with docker support', FPM::Command

    subcommand 'detect', 'Detects distribution from iamge' do

      option '--image', 'image', 'Docker image to detect'
      option '--container', 'container', 'Docker container to detect'
      option '--distribution', 'distribution', 'Distribution name to detect'

      attr :logger

      def initialize(*_)
        super
        @logger = Cabin::Channel.get
        @logger.subscribe(STDOUT)
        @logger.level = :debug
      end

      def execute
        require 'fpm/dockery/os_db'
        require 'fpm/dockery/detector'
        client = FPM::Dockery::Client.new(logger: logger)
        if image
          d = Detector::Image.new(client, image)
        elsif distribution
          d = Detector::String.new(distribution)
        else
          d = Detector::Container.new(client, container)
        end

        if d.detect!
          puts "Found #{d.distribution}/#{d.version}"
          if i = OsDb[d.distribution]
            puts "Flavour: #{i[:flavour]}"
          else
            puts "Flavour: unknown"
          end
        else
          puts "Failed"
        end
      end

    end

    subcommand 'cook', 'Cooks a package' do

      option '--distribution', 'distribution', 'Distribution like ubuntu-12.04'

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
        require 'fpm/dockery/docker_file'
        client = FPM::Dockery::Client.new(logger: logger)
        if distribution
          d = Detector::String.new(distribution)
        else
          d = Detector::Image.new(client, image)
          unless d.detect!
            logger.error("Unable to detect distribution from given image")
            return 101
          end
        end
        begin
          b = Recipe::Builder.new(distribution: d.distribution, distribution_version: d.version, image: image)
          b.load_file( recipe )
        rescue Errno::ENOENT
          logger.error("Recipe not found")
          return 1
        end

        cache = b.recipe.source.build_cache('/tmp/dockery')
        df = DockerFile.new(b.variables,cache,b.recipe)
        res = client.request('build?build=true') do |req|
          req.headers.set('Content-Tye','application/tar')
          req.method = 'POST'
          req.body = df.tar_io
        end
        res.read_http_body{|chunk| puts chunk.inspect }

        return 0
      end

    end

    subcommand 'cook2', 'Cooks a package' do

      option '--distribution', 'distribution', 'Distribution like ubuntu-12.04'

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
        require 'fpm/dockery/docker_file'
        client = FPM::Dockery::Client.new(logger: logger)
        if distribution
          d = Detector::String.new(distribution)
        else
          d = Detector::Image.new(client, image)
          unless d.detect!
            logger.error("Unable to detect distribution from given image")
            return 101
          end
        end
        begin
          b = Recipe::Builder.new(distribution: d.distribution, distribution_version: d.version, image: image)
          b.load_file( recipe )
        rescue Errno::ENOENT
          logger.error("Recipe not found")
          return 1
        end

        res = client.request('containers','create') do |req|
          req.method = 'POST'
          req.body = JSON.generate({"Image" => image})
          req.headers.set('Content-Type','application/json')
          req.headers.set('Content-Length',req.body.bytesize)
        end

        raise res.status.to_s if res.status != 201

        body = JSON.parse(res.read_body)
        container = body['Id']
        begin
          th = Thread.new do
            res = client.request('containers',container,'attach?stderr=1&stdout=1&stream=1') do |req|
              req.method = 'POST'
            end
            puts res.body.inspect
            begin
              while rd = res.body.read
                puts rd.inspect
              end
            rescue EOFError
              logger.error("eof")
            end
          end

          res = client.request('containers',container,'start') do |req|
            req.method = 'POST'
            req.body = JSON.generate({})
            req.headers.set('Content-Type','application/json')
            req.headers.set('Content-Length',req.body.bytesize)
          end

          res = client.request('containers',container,'wait') do |req|
            req.method = 'POST'
            req.body = ''
            req.headers.set('Content-Length',0)
          end

          puts res.read_body.inspect
          th.join(5) || Thread.kill(th)
        ensure
          client.request('containers',container) do |req|
            req.method = 'DELETE'
          end
        end

        return 0
      end

    end



  end

end ; end
