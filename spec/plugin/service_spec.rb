require 'fpm/dockery/plugin/service'
shared_examples 'adds script to restart services' do

  it 'has an after_install script' do
    expect( package.scripts[:after_install] ).to be_a(String)
  end

  it 'has a before_remove script' do
    expect( package.scripts[:before_remove] ).to be_a(String)
  end

  it 'lints correctly' do
    expect( recipe.lint ).to eq([])
  end
end

describe FPM::Dockery::Plugin::Service do

  let(:recipe){ FPM::Dockery::Recipe.new }

  let(:builder){
    FPM::Dockery::Recipe::Builder.new({init: init},recipe)
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
      builder.name "foo"
      builder.plugin('service') do
        command "foo","bar","baz"
      end
      builder.recipe.apply(package)
    end

    context 'for sysv' do
      let(:init){ 'sysv' }

      it_behaves_like 'adds script to restart services' 

      it 'generates an init.d script' do
        expect(File.exists? package.staging_path('/etc/init.d/foo') ).to be true
      end
    end

    context 'for upstart' do
      let(:init){ 'upstart' }

      it_behaves_like 'adds script to restart services'

      it 'generates an init.d script' do
        expect(File.exists? package.staging_path('/etc/init.d/foo') ).to be true
      end

      it 'generates an init config' do
        expect(File.exists? package.staging_path('/etc/init/foo.conf') ).to be true
      end
    end

  end

end
