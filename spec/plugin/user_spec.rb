require 'fpm/fry/plugin/user'

describe FPM::Fry::Plugin::User do

  let(:recipe){ builder.recipe }

  let(:flavour){ 'debian' }

  let(:builder){
    FPM::Fry::Recipe::Builder.new({flavour: flavour})
  }

  let(:package){
    FPM::Package.new
  }

  after(:each) do
    package.cleanup_staging
    package.cleanup_build
  end

  describe 'minimal config' do

    before(:each) do
      builder.plugin('user', 'foo')
      builder.recipe.packages[0].apply_output(package)
    end

    it 'inserts an adduser command in the postinst section' do
      expect( package.scripts[:after_install] ).to eq <<'SCRIPT'
#!/bin/bash
case "$1" in
  configure)
  adduser --system foo
  ;;
  *)
  exit 1
  ;;
esac
SCRIPT
    end

  end

  describe 'with group = true' do

    before(:each) do
      builder.plugin('user', 'foo', group: true)
      builder.recipe.packages[0].apply_output(package)
    end

    it 'inserts an adduser command in the postinst section with --group' do
      expect( package.scripts[:after_install] ).to eq <<'SCRIPT'
#!/bin/bash
case "$1" in
  configure)
  adduser --system --group foo
  ;;
  *)
  exit 1
  ;;
esac
SCRIPT
    end

  end

  describe 'with a named group' do

    before(:each) do
      builder.plugin('user', 'foo', group: "bar")
      builder.recipe.packages[0].apply_output(package)
    end

    it 'inserts an adduser command in the postinst section with --ingroup' do
      expect( package.scripts[:after_install] ).to eq <<'SCRIPT'
#!/bin/bash
case "$1" in
  configure)
  adduser --system --ingroup bar foo
  ;;
  *)
  exit 1
  ;;
esac
SCRIPT
    end

  end

  describe 'with group = something else' do

    it 'raises an ArgumentError' do
      expect{
        builder.plugin('user', 'foo', group: 123)
      }.to raise_error(ArgumentError, /:group must be a String or true/)
    end

  end
end
