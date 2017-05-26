require 'fpm/fry/recipe'
require 'fpm/fry/recipe/builder'
require 'fpm/fry/docker_file'
describe FPM::Fry::DockerFile do

  module DockerFileParams
    module ClassMethods
      def recipe
        @recipe ||= FPM::Fry::Recipe.new
        if block_given?
          yield FPM::Fry::Recipe::Builder.new(variables,recipe)
        end
        @recipe
      end

      def variables( x = nil )
        @variables = x if x
        @variables || {}
      end

      def base( x = nil )
        @base = x if x
        @base || "<base>"
      end
    end

    def variables
      self.class.variables
    end
    def cache
      FPM::Fry::Source::Null::Cache
    end
    def recipe
      self.class.recipe
    end
    def base
      self.class.base
    end

    def self.included(base)
      base.extend(ClassMethods)
    end
  end

  describe 'Build' do

    subject do
      FPM::Fry::DockerFile::Build.new(base, variables,recipe)
    end

    describe '#build_sh' do

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
echo -e '\e[1;32m====> foo\ bar\e[0m'
foo bar --baz
SHELL
        end
      end

    end

    describe '#docker_file' do

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
FROM <base>
WORKDIR /tmp/build
RUN apt-get install --yes arg blub foo
ADD .build.sh /tmp/build/
CMD /tmp/build/.build.sh
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
FROM <base>
WORKDIR /tmp/build
RUN yum -y install arg blub foo
ADD .build.sh /tmp/build/
CMD /tmp/build/.build.sh
SHELL
        end
      end

      context 'install overrides' do
        include DockerFileParams

        variables(
          image: 'ubuntu:precise',
          distribution: 'ubuntu'
        )

        recipe do |b|
          b.depends 'a'
          b.depends 'b', install: true
          b.depends 'c', install: false
          b.depends 'd', install: 'D'
          b.depends 'e', install: 'e=1.0.0'
        end

        it 'works' do
          expect(subject.dockerfile).to eq(<<SHELL)
FROM <base>
WORKDIR /tmp/build
RUN apt-get install --yes D a b e\\=1.0.0
ADD .build.sh /tmp/build/
CMD /tmp/build/.build.sh
SHELL
        end
      end

      context 'dependencies with alternatives' do
        include DockerFileParams

        variables(
          image: 'ubuntu:precise',
          distribution: 'ubuntu'
        )

        recipe do |b|
          b.depends 'a | b'
        end

        it 'works' do
          expect(subject.dockerfile).to eq(<<SHELL)
FROM <base>
WORKDIR /tmp/build
RUN apt-get install --yes a
ADD .build.sh /tmp/build/
CMD /tmp/build/.build.sh
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
          expect( entries ).to eq ['.build.sh','Dockerfile.fpm-fry']
        end

      end
    end
  end

  describe 'Source' do
    subject do
      FPM::Fry::DockerFile::Source.new(variables,cache)
    end

    describe '#docker_file' do

      context 'simple case' do
        include DockerFileParams
        let(:cache){
          c = double('cache')
          allow(c).to receive(:file_map){ {'' => '' } }
          c
        }

        variables(
          image: 'ubuntu:precise',
          distribution: 'ubuntu'
        )

        it "map the files" do
          expect(subject.dockerfile).to eq(<<DOCKERFILE)
FROM ubuntu:precise
RUN mkdir /tmp/build
ADD . /tmp/build
DOCKERFILE
        end
      end
    end

  end

=begin

=end
end

