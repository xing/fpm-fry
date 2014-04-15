require 'tmpdir'
require 'fileutils'
require 'clamp'
require 'json'

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
          puts "Distribution: #{d.distribution}"
          puts "Version: #{d.version}"
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
      option '--keep', :flag, 'Keep the container after build'
      option '--overwrite', :flag, 'Overwrite package', default: true
      option ['-t','--target'], 'target', 'Target package type (deb, rpm, ... )', default: 'auto' do |x|
        if x != 'auto' && /\A[a-z]+\z/ =~ x
          begin
            require File.join('fpm/package',x)
          rescue LoadError => e
            raise "Unknown target type: #{x}\n#{e.message}"
          end
        else
          raise "Unknown target type: #{x}"
        end
        x
      end

      parameter 'image', 'Docker image to build from'
      parameter '[recipe]', 'Recipe file to cook', default: 'recipe.rb'

      attr :logger, :out, :tmpdir

      def initialize(*_)
        super
        @logger = Cabin::Channel.get
        @logger.subscribe(STDERR)
        @logger.level = :info
        @out = STDOUT
        @tmpdir = '/tmp/dockery'
        FileUtils.mkdir_p( @tmpdir )
      end

      def execute
        require 'fpm/dockery/recipe'
        require 'fpm/dockery/detector'
        require 'fpm/dockery/docker_file'
        require 'fpm/dockery/stream_parser'
        require 'fpm/dockery/os_db'
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

        flavour = OsDb.fetch(d.distribution,{flavour: "unknown"})[:flavour]
        if target == 'auto'
          logger.info("Autodetecting package type",flavour: flavour)
          case(flavour)
          when 'debian'
            require 'fpm/package/deb'
            output_class = FPM::Package::Deb
          when 'redhat'
            require 'fpm/package/rpm'
            output_class = FPM::Package::RPM
          else
            logger.error("Cannot auto-detect package type. Please supply -t")
            return 10
          end
        else
          output_class = FPM::Package.types.fetch(target)
        end

        begin
          vars = {
            distribution: d.distribution,
            distribution_version: d.version,
            flavour: flavour
          }
          logger.info("Loading recipe",variables: vars, recipe: recipe)
          b = Recipe::Builder.new(vars)
          b.load_file( recipe )
        rescue Errno::ENOENT
          logger.error("Recipe not found")
          return 1
        end

        cache = b.recipe.source.build_cache(tmpdir)
        df = DockerFile.new(b.variables.merge(image: image),cache,b.recipe)
        res = client.request('build?build=true') do |req|
          req.headers.set('Content-Tye','application/tar')
          req.method = 'POST'
          req.body = df.tar_io
        end

        stream = ""
        res.read_http_body do |chunk|
          json = JSON.parse(chunk)
          stream = json['stream']
          out << stream
        end

        match = /\ASuccessfully built (\w+)\Z/.match(stream)
        if !match
          logger.error("Unable to detect build image")
          return 100
        end

        image = match[1]
        logger.info("Detected build image #{image.inspect}", image: image)

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
          res = client.request('containers',container,'start') do |req|
            req.method = 'POST'
            req.body = JSON.generate({})
            req.headers.set('Content-Type','application/json')
            req.headers.set('Content-Length',req.body.bytesize)
          end

          res = client.request('containers',container,'attach?stderr=1&stdout=1&stream=1') do |req|
            req.method = 'POST'
          end
          sp = StreamParser.new(STDOUT, STDERR)
          begin
            while rd = res.body.read
              sp << rd
            end
          rescue EOFError
            logger.debug("eof")
          end

          res = client.request('containers',container,'wait') do |req|
            req.method = 'POST'
            req.body = ''
            req.headers.set('Content-Length',0)
          end
          json = JSON.parse(res.read_body)
          if json["StatusCode"] != 0
            logger.error("Build failed", status_code: json['StatusCode'])
            return 102
          end

          input = FPM::Package::Docker.new(logger: logger, client: client)
          input.input(container)

          output = input.convert(output_class)

          b.recipe.apply(output)

          package_file = output.to_s(nil)
          FileUtils.mkdir_p(File.dirname(package_file))

          tmp_package_file = package_file + '.tmp'
          begin
            File.unlink tmp_package_file
          rescue Errno::ENOENT
          end

          output.output(tmp_package_file)

          begin
            File.unlink package_file
          rescue Errno::ENOENT
          end
          File.rename tmp_package_file, package_file

          logger.log("Created package", :path => package_file)
          return 0

        ensure
          unless keep?
            client.request('containers',container) do |req|
              req.method = 'DELETE'
            end
          end
        end

        return 0
      end

    end

  end

end ; end
