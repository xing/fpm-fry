require 'fileutils'
require 'fpm/package/dir'
require 'fpm/package/deb'
require 'fpm/fry/recipe'
require 'fpm/fry/recipe/builder'
require 'fpm/fry/plugin/init'
describe 'FPM::Fry::Plugin::Config' do

  let(:recipe){ builder.recipe }

  let(:builder){
    bld = FPM::Fry::Recipe::Builder.new({flavour: 'debian'})
    allow(bld).to receive(:plugin).and_call_original
    allow(bld).to receive(:plugin).with('init').and_return(init)
    bld
  }

  let(:init){ FPM::Fry::Plugin::Init::System.new(:systemd,{}) }

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


  describe '#apply' do

    context 'with a simple unit' do

      before(:each) do
        FileUtils.mkdir_p( File.join(package.staging_path, 'lib/systemd/system') )
        IO.write( File.join(package.staging_path, 'lib/systemd/system/foo.service' ), 'some service' )
        allow(logger).to receive(:info).with(/Added 1 systemd units/, Hash)
      end

      it 'adds a after_install script' do
        builder.plugin('systemd')
        recipe.packages[0].apply(package)
        expect(package.scripts[:after_install]).to include <<BASH
if systemctl is-system-running ; then
  systemctl preset foo.service
  if systemctl is-enabled foo.service ; then
    systemctl daemon-reload
    systemctl restart foo.service
  fi
fi
BASH
      end

      it 'adds a before_remove script' do
        builder.plugin('systemd')
        recipe.packages[0].apply(package)
        expect(package.scripts[:before_remove]).to include <<BASH
if systemctl is-system-running ; then
  systemctl disable --now foo.service
fi
BASH
      end

      it 'adds a after_remove script' do
        builder.plugin('systemd')
        recipe.packages[0].apply(package)
        expect(package.scripts[:after_remove]).to include <<BASH
if systemctl is-system-running ; then
  systemctl daemon-reload
  systemctl reset-failed foo.service
fi
BASH
      end
    end

  end

end
