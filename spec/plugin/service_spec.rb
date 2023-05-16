require 'fpm/package'
require 'fpm/fry/recipe/builder'
require 'fpm/fry/plugin/service'
shared_examples 'adds script to restart services' do

  it 'has an after_install script' do
    expect( package.scripts[:after_install] ).to be_a(String)
  end

  it 'has a before_remove script' do
    expect( package.scripts[:before_remove] ).to be_a(String)
  end

  it 'lints correctly' do
    expect( recipe.packages[0].lint ).to eq([])
  end
end

describe FPM::Fry::Plugin::Service do

  let(:recipe){ FPM::Fry::Recipe.new }

  let(:flavour){ 'debian' }

  let(:init){ FPM::Fry::Plugin::Init::System.new(:sysv,{}) }

  let(:builder){
    bld = FPM::Fry::Recipe::Builder.new({flavour: flavour},recipe: recipe)
    allow(bld).to receive(:plugin).and_call_original
    allow(bld).to receive(:plugin).with('init').and_return(init)
    bld
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
      builder.recipe.packages[0].apply_output(package)
    end

    context 'for sysv' do
      let(:init){ FPM::Fry::Plugin::Init::System.new(:sysv,{}) }

      it_behaves_like 'adds script to restart services'

      it 'generates an init.d script' do
        expect(File.exist? package.staging_path('/etc/init.d/foo') ).to be true
      end

      it 'adds the init script as config' do
        expect(package.config_files).to eq ['etc/init.d/foo']
      end
    end

    context 'for upstart' do
      let(:init){ FPM::Fry::Plugin::Init::System.new(:upstart,{}) }

      it_behaves_like 'adds script to restart services'

      context 'with sysvcompat' do
        let(:init){ FPM::Fry::Plugin::Init::System.new(:upstart,{sysvcompat: '/lib/init/upstart-job'}) }

        skip 'generates an init.d script' do
          expect(File.exist? package.staging_path('/etc/init.d/foo') ).to be true
        end

        it 'generates an init.d link to the upstart compat script' do
          expect(File.readlink package.staging_path('/etc/init.d/foo') ).to eq '/lib/init/upstart-job'
        end

      end

      context 'without sysvcompat' do
        let(:init){ FPM::Fry::Plugin::Init::System.new(:upstart,{sysvcompat: false}) }

        it 'doesn\'t generate an init.d script' do
          expect(File.exist? package.staging_path('/etc/init.d/foo') ).to be false
        end
      end

      it 'generates an init config' do
        expect(File.exist? package.staging_path('/etc/init/foo.conf') ).to be true
      end

      it 'generates the correct init config' do
        expect(IO.read package.staging_path('/etc/init/foo.conf') ).to eq <<'INIT'
description "a service"
start on runlevel [2345]
stop on runlevel [!2345]

env DESC="foo"
env NAME="foo"
env DAEMON="foo"
env DAEMON_ARGS="bar baz"

respawn

script
  [ -r /etc/default/$NAME ] && . /etc/default/$NAME
  exec "$DAEMON" $DAEMON_ARGS
end script
INIT
      end

      it 'adds the upstart config as config' do
        expect(package.config_files).to eq ['etc/init/foo.conf']
      end

    end

    context 'for systemd' do
      let(:init){ FPM::Fry::Plugin::Init::System.new(:systemd,{}) }

      it_behaves_like 'adds script to restart services'

      it 'generates the correct unit file' do
        expect(IO.read package.staging_path('/lib/systemd/system/foo.service') ).to eq <<'UNIT'
[Unit]
Description=

[Service]
Type=simple
ExecStart=foo bar baz
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
      end
    end
  end

  describe 'limits' do

    before(:each) do
      builder.name "foo"
      builder.plugin('service') do
        command "foo","bar","baz"
        limit 'nofile', 123,456
      end
      builder.recipe.packages[0].apply_output(package)
    end

    context 'for upstart' do
      let(:init){ FPM::Fry::Plugin::Init::System.new(:upstart,{}) }

      it 'generates an init config containing the limit' do
        expect(IO.read package.staging_path('/etc/init/foo.conf') ).to match /^limit nofile 123 456$/
      end
    end

    context 'for systemd' do
      let(:init){ FPM::Fry::Plugin::Init::System.new(:systemd,{}) }

      it 'generates an unit file containing the limit' do
        expect(IO.read package.staging_path('/lib/systemd/system/foo.service') ).to match /^LimitNOFILE=123:456$/
      end
    end

  end

  describe 'user' do

    before(:each) do
      builder.name "foo"
      builder.plugin('service') do
        command "foo","bar","baz"
        user "fuz"
      end
      builder.recipe.packages[0].apply_output(package)
    end

    context 'for upstart' do
      let(:init){ FPM::Fry::Plugin::Init::System.new(:upstart,{}) }

      it 'generates an init config containing the user' do
        expect(IO.read package.staging_path('/etc/init/foo.conf') ).to match /^setuid "fuz"$/
      end
    end

    context 'for sysv' do
      let(:init){ FPM::Fry::Plugin::Init::System.new(:sysv,{}) }

      it 'generates an init script containing the user' do
        expect(IO.read package.staging_path('/etc/init.d/foo') ).to match /start-stop-daemon --start --quiet --pidfile \$PIDFILE --background -c fuz --exec/
      end
    end

    context 'for systemd' do
      let(:init){ FPM::Fry::Plugin::Init::System.new(:systemd,{}) }

      it 'generates an unit file containing the user' do
        expect(IO.read package.staging_path('/lib/systemd/system/foo.service') ).to match /^User=fuz$/
      end
    end
  end

  describe 'group' do

    before(:each) do
      builder.name "foo"
      builder.plugin('service') do
        command "foo","bar","baz"
        group "fuz"
      end
      builder.recipe.packages[0].apply_output(package)
    end

    context 'for upstart' do
      let(:init){ FPM::Fry::Plugin::Init::System.new(:upstart,{}) }

      it 'generates an init config containing the group' do
        expect(IO.read package.staging_path('/etc/init/foo.conf') ).to match /^setgid "fuz"$/
      end
    end

    context 'for sysv' do
      let(:init){ FPM::Fry::Plugin::Init::System.new(:sysv,{}) }

      it 'generates an init script containing the group' do
        expect(IO.read package.staging_path('/etc/init.d/foo') ).to match /start-stop-daemon --start --quiet --pidfile \$PIDFILE --background -g fuz --exec/
      end
    end

    context 'for systemd' do
      let(:init){ FPM::Fry::Plugin::Init::System.new(:systemd,{}) }

      it 'generates an unit file containing the group' do
        expect(IO.read package.staging_path('/lib/systemd/system/foo.service') ).to match /^Group=fuz$/
      end
    end
  end

  describe 'chdir' do

    before(:each) do
      builder.name "foo"
      builder.plugin('service') do
        command "foo","bar","baz"
        chdir "/fuz"
      end
      builder.recipe.packages[0].apply_output(package)
    end

    context 'for upstart' do
      let(:init){ FPM::Fry::Plugin::Init::System.new(:upstart,{}) }

      it 'generates an init config containing the chdir' do
        expect(IO.read package.staging_path('/etc/init/foo.conf') ).to match /^chdir "\/fuz"$/
      end
    end

    context 'for sysv' do
      let(:init){ FPM::Fry::Plugin::Init::System.new(:sysv,{}) }

      it 'generates an init script containing the chdir' do
        expect(IO.read package.staging_path('/etc/init.d/foo') ).to match /start-stop-daemon --start --quiet --pidfile \$PIDFILE --background -d \/fuz --exec/
      end
    end

    context 'for systemd' do
      let(:init){ FPM::Fry::Plugin::Init::System.new(:systemd,{}) }

      it 'generates an unit file containing the chdir' do
        expect(IO.read package.staging_path('/lib/systemd/system/foo.service') ).to match /^WorkingDirectory=\/fuz$/
      end
    end
  end

end
