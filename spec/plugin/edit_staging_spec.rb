require 'fpm/package/dir'
require 'fpm/fry/recipe'
require 'fpm/fry/recipe/builder'
describe 'FPM::Fry::Plugin::EditStaging' do

  let(:recipe){ builder.recipe }

  let(:builder){
    FPM::Fry::Recipe::Builder.new({})
  }

  let(:package){
    FPM::Package::Dir.new
  }

  after(:each) do
    package.cleanup_staging
    package.cleanup_build
  end

  describe '#apply' do
    context 'with a unary block' do
      it 'yields a dsl' do
        yielded = nil
        builder.plugin('edit_staging'){|dsl|
          yielded = dsl
        }
        expect(yielded).to respond_to :add_file
        expect(yielded).to respond_to :ln_s
      end
    end

    context 'with a argless block' do
      it 'instance_execs a dsl' do
        yielded = nil
        builder.plugin('edit_staging'){
          yielded = self
        }
        expect(yielded).to respond_to :add_file
        expect(yielded).to respond_to :ln_s
      end
    end

    context 'without a block' do
      it 'returns a dsl' do
        returned = builder.plugin('edit_staging')
        expect(returned).to respond_to :add_file
        expect(returned).to respond_to :ln_s
      end
    end
  end

  describe '#add_file' do
    context 'with an IO' do
      before(:each) do
        builder.plugin('edit_staging') do
          add_file '/etc/init.d/foo', StringIO.new('#!foo')
        end
        recipe.packages[0].apply(package)
      end

      it "contains the given content" do
        expect(File.read package.staging_path('/etc/init.d/foo') ).to eq '#!foo'
      end
    end

    context 'with a String' do
      before(:each) do
        builder.plugin('edit_staging') do
          add_file '/etc/init.d/foo', '#!foo'
        end
        recipe.packages[0].apply(package)
      end

      it "contains the given content" do
        expect(File.read package.staging_path('/etc/init.d/foo') ).to eq '#!foo'
      end
    end

    context 'with an unknown content' do
      it "raises an error" do
        expect do
          builder.plugin('edit_staging') do
            add_file '/etc/init.d/foo', Object.new
          end
        end.to raise_error(ArgumentError,/File content must be a String or IO/)
      end
    end

    context 'with string chmod' do
      before(:each) do
        builder.plugin('edit_staging') do
          add_file '/etc/init.d/foo', '#!foo', chmod: '0750'
        end
        recipe.packages[0].apply(package)
      end

      it "contains the given file" do
        expect(File.stat(package.staging_path('/etc/init.d/foo')).mode.to_s(8) ).to eq '100750'
      end
    end

    context 'with numeric chmod' do
      before(:each) do
        builder.plugin('edit_staging') do
          add_file '/etc/init.d/foo', '#!foo', chmod: 0750
        end
        recipe.packages[0].apply(package)
      end

      it "contains the given file" do
        expect(File.stat(package.staging_path('/etc/init.d/foo')).mode.to_s(8) ).to eq '100750'
      end
    end

    context 'with invalid chmod' do
      it "raises an error" do
        expect do
          builder.plugin('edit_staging') do
            add_file '/etc/init.d/foo', "foo", chmod: Object.new
          end
        end.to raise_error(ArgumentError,/Invalid chmod format:/)
      end
    end

  end

  describe '#ln_s' do
    context 'simple case' do
      before(:each) do
        builder.plugin('edit_staging') do
          ln_s '/lib/init/upstart-job', '/etc/init.d/foo'
        end
        recipe.packages[0].apply(package)
      end

      it "contains the given file" do
       expect(File.readlink package.staging_path('/etc/init.d/foo') ).to eq '/lib/init/upstart-job'
      end
    end
  end

end
