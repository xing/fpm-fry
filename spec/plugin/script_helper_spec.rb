require 'fpm/package/dir'
require 'fpm/package/deb'
require 'fpm/fry/recipe'
require 'fpm/fry/recipe/builder'
describe 'FPM::Fry::Plugin::ScriptHelper' do

  let(:flavour){ 'debian' }

  let(:recipe){ builder.recipe }

  let(:builder){
    FPM::Fry::Recipe::Builder.new({flavour: flavour})
  }

  after(:each) do
    package.cleanup_staging
    package.cleanup_build
  end

  let(:package){
    pack = FPM::Package::Dir.new
    pack.instance_variable_set(:@logger,logger)
    pack
  }

  describe '#apply' do

    context 'with a unary block' do
      it 'yields a dsl' do
        yielded = nil
        builder.plugin('script_helper'){|dsl|
          yielded = dsl
        }
        expect(yielded).to respond_to :after_install_or_upgrade
        expect(yielded).to respond_to :before_remove_entirely
      end
    end

  end

  describe '#after_install_or_upgrade' do
    context 'with a string' do
      before(:each) do
        builder.plugin('script_helper') do
          after_install_or_upgrade 'do-foo'
        end
        recipe.packages[0].apply(package)
      end

      context 'on debian' do
        it 'renders an after_install script' do
          expect(package.scripts[:after_install]).to match /configure[)]\s*do-foo/
        end
      end

      context 'on redhat' do
        let(:flavour){'redhat'}

        it 'renders an after_install script' do
          expect(package.scripts[:after_install]).to eq "#!/bin/bash\ndo-foo\n"
        end

        it 'renders an after_install script' do
          expect(package.scripts[:after_install]).to eq "#!/bin/bash\ndo-foo\n"
        end
      end
    end
  end

  describe '#after_remove_entirely' do
    context 'with a string' do
      before(:each) do
        builder.plugin('script_helper') do
          after_remove_entirely 'do-foo'
        end
        recipe.packages[0].apply(package)
      end

      context 'on debian' do
        it 'renders an after_remove script' do
          expect(package.scripts[:after_remove]).to match /remove[)]\s*do-foo/
        end
      end

      context 'on redhat' do
        let(:flavour){'redhat'}

        it 'renders an after_install script' do
          expect(package.scripts[:after_remove]).to match /do-foo/
        end
      end
    end
  end


end
