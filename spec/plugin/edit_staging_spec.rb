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

    context 'with chmod' do
      before(:each) do
        builder.plugin('edit_staging') do
          add_file '/etc/init.d/foo', StringIO.new('#!foo'), chmod: '0750'
        end
        recipe.apply(package)
      end

      it "contains the given file" do
        expect(File.stat(package.staging_path('/etc/init.d/foo')).mode.to_s(8) ).to eq '100750'
      end

    end
  end

  describe '#ln_s' do
    context 'simple case' do
      before(:each) do
        builder.plugin('edit_staging') do
          ln_s '/lib/init/upstart-job', '/etc/init.d/foo'
        end
        recipe.apply(package)
      end

      it "contains the given file" do
       expect(File.readlink package.staging_path('/etc/init.d/foo') ).to eq '/lib/init/upstart-job'
      end
    end
  end

end
