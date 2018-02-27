require 'fpm/fry/plugin/env'
require 'fpm/fry/recipe'
require 'fpm/fry/recipe/builder'
require 'fpm/fry/docker_file'

describe FPM::Fry::Plugin::Env do
  describe '#apply' do
    let(:builder){
      FPM::Fry::Recipe::Builder.new({flavour: 'debian'})
    }

    it 'adds ENV instructions to the docker file' do
      builder.plugin('env', 'FOO' => 'bar', 'PATH' => '$PATH:/foo/bin', 'MULTI'=> "line\nline", "SPACE"=>"space space")
      df = FPM::Fry::DockerFile::Build.new('<base>',builder.variables,builder.recipe)
      expect(df.dockerfile).to include "ENV FOO=bar PATH=$PATH:/foo/bin MULTI=line\\\nline SPACE=space\\ space\n"
    end

    it 'adds ENV instructions to the docker file when passed as symbols' do
      builder.plugin('env', FOO: 'bar', PATH: '$PATH:/foo/bin', MULTI: "line\nline", SPACE: "space space")
      df = FPM::Fry::DockerFile::Build.new('<base>',builder.variables,builder.recipe)
      expect(df.dockerfile).to include "ENV FOO=bar PATH=$PATH:/foo/bin MULTI=line\\\nline SPACE=space\\ space\n"
    end

    it 'barfs when ENV is not a hash' do
      expect{
        builder.plugin('env', double(:something_else))
      }.to raise_error(ArgumentError, /ENV must be a Hash/){|e|
        expect(e.data).to include(documentation: %r!/fpm-fry/wiki/Plugin-env!)
      }
    end

    it 'barfs when ENV keys aren\'t strings' do
      expect{
        builder.plugin('env', double(:something_else) => "foo")
      }.to raise_error(ArgumentError, /environment variable names must/){|e|
        expect(e.data).to include(documentation: %r!/fpm-fry/wiki/Plugin-env!)
      }
    end


  end
end
