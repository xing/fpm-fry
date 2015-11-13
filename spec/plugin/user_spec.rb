require 'fpm/fry/plugin/user'

describe FPM::Fry::Plugin::User do

  let(:recipe){ FPM::Fry::Recipe.new }

  let(:flavour){ 'debian' }

  let(:builder){
    FPM::Fry::Recipe::Builder.new({flavour: flavour},recipe)
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

end
