require 'fpm/fry/plugin/apt'
require 'fpm/fry/recipe'
require 'fpm/fry/recipe/builder'

describe FPM::Fry::Plugin::Apt do

  describe '#apply' do
    let(:builder){
      FPM::Fry::Recipe::Builder.new({flavour: flavour})
    }

    context 'with a debian' do
      let(:flavour){ 'debian' }
      it 'yields' do
        expect{|yld|
          builder.plugin('apt',&yld)
        }.to yield_with_args(FPM::Fry::Plugin::Apt)
      end
    end

    context 'with something else' do
      let(:flavour){ 'something else' }
      it 'doesn\'t yield' do
        expect{|yld|
          builder.plugin('apt',&yld)
        }.not_to yield_control
      end
    end
  end

  describe '.repository' do

    let(:flavour){ 'debian' }
    let(:builder){
      FPM::Fry::Recipe::Builder.new({flavour: flavour})
    }
    let(:recipe){
      builder.recipe
    }

    context 'simple case' do
      before(:each) do
        builder.plugin('apt') do |apt|
          apt.repository "https://examp.le/","foo","bar"
        end
      end

      it 'adds a repository' do
        expect(recipe.before_dependencies_steps).to match [/^echo 'deb.+ && apt-get update.+/]
      end
    end

  end

end
