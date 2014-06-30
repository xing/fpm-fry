require 'fpm/package/dir'
require 'fpm/dockery/recipe'
describe 'FPM::Dockery::Plugin::Exclude' do

  let(:recipe){ FPM::Dockery::Recipe.new }

  let(:builder){
    FPM::Dockery::Recipe::Builder.new({},recipe)
  }

  let(:package){
    FPM::Package::Dir.new
  }

  after(:each) do
    package.cleanup_staging
    package.cleanup_build
  end

  describe '#exclude' do
    before(:each) do
      builder.plugin('exclude')
      builder.exclude('foo/**/bar')
      recipe.apply_input(package)
    end

    it "contains the given file" do
      expect(package.attributes[:excludes] ).to eq ['foo/**/bar']
    end
  end

end
