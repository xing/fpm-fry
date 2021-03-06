require 'fpm/package/dir'
require 'fpm/package/deb'
require 'fpm/fry/recipe'
require 'fpm/fry/recipe/builder'
describe 'FPM::Fry::Plugin::Config' do

  let(:recipe){ builder.recipe }

  let(:builder){
    FPM::Fry::Recipe::Builder.new({})
  }

  after(:each) do
    package.cleanup_staging
    package.cleanup_build
  end

  let(:package){
    pack = FPM::Package::Dir.new
    Dir.mkdir( File.join(pack.staging_path, "etc") )
    pack.instance_variable_set(:@logger,logger)
    pack
  }

  describe '#include' do

    context 'with a simple file' do
      before(:each) do
        File.open( File.join(package.staging_path, "foo"), 'w' ){}
        builder.plugin('config') do
          include '/foo'
        end
        recipe.packages[0].apply(package)
      end

      it "adds the file to the config file list" do
        expect(package.config_files).to eq ['foo']
      end
    end

    context 'with a directory file' do
      before(:each) do
        Dir.mkdir( File.join(package.staging_path, "foo") )
        File.open( File.join(package.staging_path, "foo/bar"), 'w' ){}
        builder.plugin('config') do
          include '/foo'
        end
        recipe.packages[0].apply(package)
      end

      it "adds all files recursively to the config file list" do
        expect(package.config_files).to eq ['foo/bar']
      end
    end

    context 'with a file that doesn\'t exist' do

      before(:each) do
        builder.plugin('config') do
          include '/foo'
        end
      end

      it "warns about a missing file" do
        expect(logger).to receive(:warn).with("Config path not found", path: 'foo', documentation: String, plugin: 'config')
        recipe.packages[0].apply(package)
        expect(package.config_files).to eq []
      end
    end

    context 'with a symlink' do
      before(:each) do
        File.open( File.join(package.staging_path, "bar"), 'w' ){}
        File.symlink( "/bar", File.join(package.staging_path, "foo") )
        builder.plugin('config') do
          include '/foo'
        end
      end

      it "ignores the symlink" do
        expect(logger).to receive(:warn).with("Config file is a symlink", path: 'foo', plugin: 'config', documentation: String)
        recipe.packages[0].apply(package)
        expect(package.config_files).to eq []
      end
    end

  end

  describe '#exclude' do
    context 'with just etc' do
      before(:each) do
        File.open( File.join(package.staging_path, "etc/foo"), 'w' ){}
        builder.plugin('config') do
          exclude 'etc'
        end
        recipe.packages[0].apply(package)
      end

      it "removes the directory" do
        expect(package.config_files).to eq []
      end
    end

    context 'with single files' do
      before(:each) do
        File.open( File.join(package.staging_path, "etc/foo"), 'w' ){}
        File.open( File.join(package.staging_path, "etc/bar"), 'w' ){}
        builder.plugin('config') do
          exclude 'etc/foo'
        end
        recipe.packages[0].apply(package)
      end

      it "removes just the given file" do
        expect(package.config_files).to eq ['etc/bar']
      end
    end

    context 'with a nested include' do
      before(:each) do
        File.open( File.join(package.staging_path, "etc/foo"), 'w' ){}
        Dir.mkdir( File.join(package.staging_path, "etc/bar") )
        File.open( File.join(package.staging_path, "etc/bar/foo"), 'w' ){}
        File.open( File.join(package.staging_path, "etc/bar/baz"), 'w' ){}
        builder.plugin('config') do
          exclude 'etc/bar'
          include 'etc/bar/baz'
        end
        recipe.packages[0].apply(package)
      end

      it "removes all but the explictly added files" do
        expect(package.config_files).to eq ['etc/foo', 'etc/bar/baz']
      end
    end

  end

  describe 'default behavior' do
    before(:each) do
      File.open( File.join(package.staging_path, "etc/foo"), 'w' ){}
      builder.plugin('config') do
      end
      recipe.packages[0].apply(package)
    end

    it "adds etc directory" do
      expect(package.config_files).to eq ['etc/foo']
    end

    it "flags the package" do
      expect(package.attributes[:fry_config_explicitly_used]).to be true
    end
  end

  describe 'implicit usage' do
    before(:each) do
      File.open( File.join(package.staging_path, "etc/foo"), 'w' ){}
      builder.plugin('config', FPM::Fry::Plugin::Config::IMPLICIT => true) do
      end
      recipe.packages[0].apply(package)
    end

    it "adds etc directory" do
      expect(package.config_files).to eq ['etc/foo']
    end

    it "doesn't flag the package" do
      expect(package.attributes[:fry_config_explicitly_used]).not_to be true
    end
  end

end
