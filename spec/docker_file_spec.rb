require 'fpm/dockery/recipe'
require 'fpm/dockery/docker_file'
describe FPM::Dockery::DockerFile do

  module DockerFileParams
    module ClassMethods
      def recipe
        @recipe ||= FPM::Dockery::Recipe.new
        if block_given?
          yield FPM::Dockery::Recipe::Builder.new(variables,recipe)
        end
        @recipe
      end

      def cache( x = nil )
        @cache = x if x
        @cache || FPM::Dockery::Source::Null::Cache
      end

      def variables( x = nil )
        @variables = x if x
        @variables || {}
      end
    end

    def variables
      self.class.variables
    end
    def cache
      self.class.cache
    end
    def recipe
      self.class.recipe
    end

    def self.included(base)
      base.extend(ClassMethods)
    end
  end

  subject do
    FPM::Dockery::DockerFile.new(variables,cache,recipe)
  end

  describe 'build_sh' do

    context 'simple case' do
      include DockerFileParams

      variables(
        image: 'ubuntu:precise',
        distribution: 'ubuntu'
      )

      recipe do |b|
        b.run "foo", "bar", "--baz"
      end

      it 'works' do
        expect(subject.build_sh).to eq(<<'SHELL')
#!/bin/bash
set -e
echo -e '\e[1;32m====> foo-bar\e[0m'
foo bar --baz
SHELL
      end
    end

  end

  describe 'docker_file' do

    context 'simple ubuntu' do
      include DockerFileParams

      variables(
        image: 'ubuntu:precise',
        distribution: 'ubuntu'
      )

      recipe do |b|
        b.build_depends 'blub'
        b.depends 'foo'
        b.depends 'arg'
      end

      it 'works' do
        expect(subject.dockerfile).to eq(<<SHELL)
FROM ubuntu:precise
RUN mkdir /tmp/build
WORKDIR /tmp/build
RUN apt-get install --yes arg blub foo
ADD .build.sh /tmp/build/
ENTRYPOINT /tmp/build/.build.sh
SHELL
      end
    end

    context 'simple centos' do
      include DockerFileParams

      variables(
        image: 'centos:6.5',
        distribution: 'centos'
      )

      recipe do |b|
        b.build_depends 'blub'
        b.depends 'foo'
        b.depends 'arg'
      end

      it 'works' do
        expect(subject.dockerfile).to eq(<<SHELL)
FROM centos:6.5
RUN mkdir /tmp/build
WORKDIR /tmp/build
RUN yum -y install arg blub foo
ADD .build.sh /tmp/build/
ENTRYPOINT /tmp/build/.build.sh
SHELL
      end
    end

    context 'with cache files' do

      let(:cache){
        double(:cache)
      }

      subject do
        FPM::Dockery::DockerFile.new({image: 'ubuntu:precise',distribution: 'ubuntu'},cache,FPM::Dockery::Recipe.new)
      end

      it 'maps files' do
        expect(cache).to receive(:file_map).and_return({''=>''})
        expect(subject.dockerfile).to eq(<<SHELL)
FROM ubuntu:precise
RUN mkdir /tmp/build
WORKDIR /tmp/build
ADD . /tmp/build
ADD .build.sh /tmp/build/
ENTRYPOINT /tmp/build/.build.sh
SHELL
      end

    end
  end

  describe '#tar_io' do

     context 'simple ubuntu' do
      include DockerFileParams

      variables(
        image: 'ubuntu:precise',
        distribution: 'ubuntu'
      )

      it 'works' do
        io = subject.tar_io
        entries = Gem::Package::TarReader.new(io).map{|e| e.header.name }
        expect( entries ).to eq ['.build.sh','Dockerfile']
      end

    end
  end
end

