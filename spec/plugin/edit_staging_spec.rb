require 'fpm/package/dir'
require 'fpm/dockery/recipe'
describe 'FPM::Dockery::Plugin::EditStaging' do

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

  describe '#add_file' do

    context 'with an IO' do

      before(:each) do
        builder.plugin('edit_staging') do
          add_file '/etc/init.d/foo', StringIO.new('#!foo')
        end
        recipe.apply(package)
      end

      it "contains the given file" do
        expect(File.read package.staging_path('/etc/init.d/foo') ).to eq '#!foo'
      end

    end
  end
end
