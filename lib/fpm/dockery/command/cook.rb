require 'fpm/dockery/command'
module FPM; module Dockery
  class Command::Cook < Command

    option '--distribution', 'distribution', 'Distribution like ubuntu-12.04'
    option '--keep', :flag, 'Keep the container after build'
    option '--overwrite', :flag, 'Overwrite package', default: true

    UPDATE_VALUES = ['auto','never','always']
    option '--update',"<#{UPDATE_VALUES.join('|')}>", 'Update image before installing packages ( only apt currently )',attribute_name: 'update', default: 'auto' do |value|
      if !UPDATE_VALUES.include? value
        raise "Unknown value for --update: #{value.inspect}\nPossible values are #{UPDATE_VALUES.join(', ')}"
      else
        value
      end
    end

    parameter 'image', 'Docker image to build from'
    parameter '[recipe]', 'Recipe file to cook', default: 'recipe.rb'

    attr :ui
    extend Forwardable
    def_delegators :ui, :out, :err, :logger, :tmpdir

    def initialize(invocation_path, ctx = {}, parent_attribute_values = {})
      @tls = nil
      require 'digest'
      require 'fpm/dockery/recipe'
      require 'fpm/dockery/recipe/builder'
      require 'fpm/dockery/detector'
      require 'fpm/dockery/docker_file'
      require 'fpm/dockery/stream_parser'
      require 'fpm/dockery/os_db'
      require 'fpm/dockery/block_enumerator'
      require 'fpm/dockery/build_output_parser'
      super
      @ui = ctx.fetch(:ui){ UI.new }
      if debug?
        ui.logger.level = :debug
      end
    end

    def detector
      @detector || begin
        if distribution
          d = Detector::String.new(distribution)
        else
          d = Detector::Image.new(client, image)
        end
        self.detector=d
      end
    end

    def detector=(d)
      begin
        unless d.detect!
          raise "Unable to detect distribution from given image"
        end
      rescue Excon::Errors::NotFound
        raise "Image not found"
      end
      @detector = d
    end

    def flavour
      @flavour ||= OsDb.fetch(detector.distribution,{flavour: "unknown"})[:flavour]
    end
    attr_writer :flavour

    def output_class
      @output_class ||= begin
        logger.info("Autodetecting package type",flavour: flavour)
        case(flavour)
        when 'debian'
          require 'fpm/package/deb'
          FPM::Package::Deb
        when 'redhat'
          require 'fpm/package/rpm'
          FPM::Package::RPM
        else
          raise "Cannot auto-detect package type."
        end
      end
    end
    attr_writer :output_class

    def builder
      @builder ||= begin
        vars = {
          distribution: detector.distribution,
          distribution_version: detector.version,
          flavour: flavour
        }
        logger.info("Loading recipe",variables: vars, recipe: recipe)
        b = Recipe::Builder.new(vars, Recipe.new, logger: ui.logger)
        b.load_file( recipe )
        b
      end
    end
    attr_writer :builder

    def cache
      @cache ||= builder.recipe.source.build_cache(tmpdir)
    end
    attr_writer :cache

    def lint_output_class!

    end

    def lint_recipe_file!
      File.exists?(recipe) || raise(Recipe::NotFound)
    end

    def lint_recipe!
      problems = builder.recipe.lint
      if problems.any?
        problems.each do |p|
          logger.error(p)
        end
        raise
      end
    end

    def image_id
      @image_id ||= begin
        res = client.get(
          expects: [200],
          path: client.url("images/#{image}/json")
        )
        body = JSON.parse(res.body)
        body.fetch('id'){ body.fetch('Id') }
      end
    end
    attr_writer :image_id

    def build_image
      @build_image ||= begin
        sum = Digest::SHA256.hexdigest( image_id + "\0" + cache.cachekey )
        cachetag = "fpm-dockery:#{sum[0..30]}"
        res = client.get(
          expects: [200,404],
          path: client.url("images/#{cachetag}/json")
        )
        if res.status == 404
          df = DockerFile::Source.new(builder.variables.merge(image: image_id),cache)
          client.post(
            headers: {
              'Content-Type'=>'application/tar'
            },
            expects: [200],
            path: client.url("build?rm=1&t=#{cachetag}"),
            request_block: BlockEnumerator.new(df.tar_io)
          )
        end

        df = DockerFile::Build.new(cachetag, builder.variables.dup,builder.recipe, update: update?)
        parser = BuildOutputParser.new(out)
        res = client.post(
          headers: {
            'Content-Type'=>'application/tar'
          },
          expects: [200],
          path: client.url('build?rm=1'),
          request_block: BlockEnumerator.new(df.tar_io),
          response_block: parser
        )
        if parser.images.none?
          raise "Unable to detect build image"
        end
        image = parser.images.last
        logger.debug("Detected build image", image: image)
        image
      end
    end
    attr_writer :build_image

    def update?
      if flavour == 'debian'
        case(update)
        when 'auto'
          body = JSON.generate({"Image" => image, "Cmd" => "exit 0"})
          res = client.post( path: client.url('containers','create'),
                             headers: {'Content-Type' => 'application/json'},
                             body: body,
                             expects: [201]
                           )
          body = JSON.parse(res.body)
          container = body.fetch('Id')
          begin
            client.read( container, '/var/lib/apt/lists') do |file|
              next if file.header.name == 'lists/'
              logger.info("/var/lib/apt/lists is not empty, no update is required ( force update with --apt-update=always )")
              return false
            end
          ensure
            client.delete(path: client.url('containers',container))
          end
          logger.info("/var/lib/apt/lists is empty, update is required ( disable update with --apt-update=never )")
          return true
        when 'always'
          return true
        when 'never'
          return false
        end
      else
        return false
      end
    end

    def build!
      res = client.post(
         headers: {
          'Content-Type' => 'application/json'
         },
         path: client.url('containers','create'),
         expects: [201],
         body: JSON.generate({"Image" => build_image})
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
            StreamParser.new(out,err),
            Excon::Middleware::Expects,
            Excon::Middleware::Instrumentor,
            Excon::Middleware::Mock
          ]
        )

        res = client.post(
          path: client.url('containers',container,'wait'),
          expects: [200],
          body: ''
        )
        json = JSON.parse(res.body)
        if json["StatusCode"] != 0
          raise "Build failed"
        end
        return yield container
      ensure
        unless keep?
          client.delete(path: client.url('containers',container))
        end
      end
    end

    def input_package(container)
      input = FPM::Package::Docker.new(logger: logger, client: client)
      builder.recipe.apply_input(input)
      begin
        input.input(container)
        return yield(input)
      ensure
        input.cleanup_staging
        input.cleanup_build
      end
    end

    def write_output!(output)
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
    end

  public

    def execute
      # force some eager loading
      lint_recipe_file!
      detector
      flavour
      output_class
      lint_output_class!
      builder
      lint_recipe!
      cache

      image_id
      build_image

      build! do |container|
        input_package(container) do |input|
          output = input.convert(output_class)
          output.instance_variable_set(:@logger,logger)
          begin
            builder.recipe.apply_output(output)
            write_output!( output )
          ensure
            output.cleanup_staging
            output.cleanup_build
          end
        end
      end
      return 0
    rescue Recipe::NotFound => e
      logger.error("Recipe not found", recipe: recipe, exeception: e)
      return 1
    rescue => e
      logger.error(e)
      return 1
    end

  end

  class Command
    subcommand 'cook', 'Cooks a package', Cook
  end
end ; end
