require 'clamp'
module FPM; module Dockery

  class Command < Clamp::Command

    subcommand 'fpm', 'Works like fpm but with docker support', FPM::Command
    subcommand 'cook', 'Cooks a package' do

      option '--distribution', 'distribution', 'Distribution like ubuntu-12.04', default: 'ubuntu-12.04'

      parameter 'image', 'Docker image to build from'
      parameter '[recipe]', 'Recipe file to cook', default: 'recipe.rb'

      def execute
        require 'fpm/dockery/recipe'
        require 'fpm/dockery/recipe/dsl'
        r = FPM::Dockery::Recipe::DSL.from_file( recipe )
        distro, distro_version = distribution.split('-',2)
        build = {distro: distro, distro_version: distro_version, from: image}
        config = r.configuration(build)
        puts config.dockerfile
        puts '============'
        puts config.build_sh
        return 0
      end

    end


  end

end ; end
