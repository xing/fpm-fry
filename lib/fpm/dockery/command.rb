require 'tmpdir'
require 'fileutils'
require 'clamp'
require 'json'
require 'forwardable'
require 'fpm/dockery/ui'

module FPM; module Dockery

  class Command < Clamp::Command

    option '--debug', :flag, 'Turns on debugging'

    subcommand 'fpm', 'Works like fpm but with docker support', FPM::Command

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
        client = FPM::Dockery::Client.new(logger: logger)
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

      attr :ui
      extend Forwardable
      def_delegators :ui, :out, :err, :logger, :tmpdir

      def initialize(*_)
        super
        @ui = UI.new
        if debug?
          ui.logger.level = :debug
        end
      end

      def execute
        require 'fpm/dockery/recipe'
        require 'fpm/dockery/detector'
        require 'fpm/dockery/docker_file'
        require 'fpm/dockery/stream_parser'
        require 'fpm/dockery/os_db'
        require 'fpm/dockery/block_enumerator'
        require 'fpm/dockery/build_output_parser'
        client = FPM::Dockery::Client.new(logger: logger)
        if distribution
          d = Detector::String.new(distribution)
        else
          d = Detector::Image.new(client, image)
          begin
            unless d.detect!
              logger.error("Unable to detect distribution from given image")
              return 101
            end
          rescue Excon::Errors::NotFound
            logger.error("Image not found", image: image)
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
          b = Recipe::Builder.new(vars, Recipe.new, logger: ui.logger)
          b.load_file( recipe )
        rescue Recipe::NotFound => e
          logger.error("Recipe not found", recipe: recipe, exeception: e)
          return 1
        end

        problems = b.recipe.lint
        if problems.any?
          problems.each do |p|
            logger.error(p)
          end
          return 1
        end

        begin
          cache = b.recipe.source.build_cache(tmpdir)
        rescue Source::CacheFailed => e
          logger.error(e.message, e.options)
          return 100
        end

        df = DockerFile.new(b.variables.merge(image: image),cache,b.recipe)

        parser = BuildOutputParser.new(out)
        tar_io = df.tar_io

        res = client.post(
          headers: {
            'Content-Type'=>'application/tar'
          },
          expects: [200],
          path: client.url('build?rm=1'),
          request_block: BlockEnumerator.new(tar_io),
          response_block: parser
        )

        if parser.images.none?
          logger.error("Unable to detect build image")
          return 100
        end

        image = parser.images.last
        logger.debug("Detected build image", image: image)

        res = client.post(
           headers: {
            'Content-Type' => 'application/json'
           },
           path: client.url('containers','create'),
           expects: [201],
           body: JSON.generate({"Image" => image})
        )

        body = JSON.parse(res.body)
        container = body['Id']
        begin
          client.post(
            headers: {
              'Content-Type' => 'application/json'
            },
            path: client.url('containers',container,'start'),
            expects: [204],
            body: JSON.generate({})
          )

          client.post(
            path: client.url('containers',container,'attach?stderr=1&stdout=1&stream=1'),
            body: '',
            expects: [200],
            middlewares: [
              StreamParser.new(STDOUT,STDERR),
              Excon::Middleware::Expects,
              Excon::Middleware::Instrumentor
            ]
          )

          res = client.post(
            path: client.url('containers',container,'wait'),
            expects: [200],
            body: ''
          )
          json = JSON.parse(res.body)
          if json["StatusCode"] != 0
            logger.error("Build failed", status_code: json['StatusCode'])
            return 102
          end

          input = FPM::Package::Docker.new(logger: logger, client: client)
          b.recipe.apply_input(input)
          begin
            input.input(container)
            output = input.convert(output_class)
            output.instance_variable_set(:@logger,logger)
            begin
              b.recipe.apply_output(output)

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

              logger.info("Created package", :path => package_file)
              return 0
            ensure
              output.cleanup_staging
              output.cleanup_build
            end
          ensure
            input.cleanup_staging
            input.cleanup_build
          end
        ensure
          unless keep?
            client.delete(path: client.url('containers',container))
          end
        end

        return 0
      rescue => e
        logger.error(e)
        return 1
      end

    end

  end

end ; end
