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

  let(:builder){
    FPM::Fry::Recipe::Builder.new({init: init, flavour: flavour},recipe)
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
      let(:init){ 'sysv' }

      it_behaves_like 'adds script to restart services' 

      it 'generates an init.d script' do
        expect(File.exists? package.staging_path('/etc/init.d/foo') ).to be true
      end

      it 'adds the init script as config' do
        expect(package.config_files).to eq ['etc/init.d/foo']
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

      it 'adds the init script and the upstart config as config' do
        expect(package.config_files).to eq ['etc/init/foo.conf','etc/init.d/foo']
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
      let(:init){ 'upstart' }

      it 'generates an init config containing the limit' do
        expect(IO.read package.staging_path('/etc/init/foo.conf') ).to match /^limit nofile 123 456$/
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
      let(:init){ 'upstart' }

      it 'generates an init config containing the user' do
        expect(IO.read package.staging_path('/etc/init/foo.conf') ).to match /^setuid "fuz"$/
      end
    end

    context 'for sysv' do
      let(:init){ 'sysv' }

      it 'generates an init script containing the user' do
        expect(IO.read package.staging_path('/etc/init.d/foo') ).to match /start-stop-daemon --start --quiet --pidfile \$PIDFILE --background -c fuz --exec/
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
      let(:init){ 'upstart' }

      it 'generates an init config containing the user' do
        expect(IO.read package.staging_path('/etc/init/foo.conf') ).to match /^setgid "fuz"$/
      end
    end

    context 'for sysv' do
      let(:init){ 'sysv' }

      it 'generates an init script containing the user' do
        expect(IO.read package.staging_path('/etc/init.d/foo') ).to match /start-stop-daemon --start --quiet --pidfile \$PIDFILE --background -g fuz --exec/
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
      let(:init){ 'upstart' }

      it 'generates an init config containing the chdir' do
        expect(IO.read package.staging_path('/etc/init/foo.conf') ).to match /^chdir "\/fuz"$/
      end
    end

    context 'for sysv' do
      let(:init){ 'sysv' }

      it 'generates an init script containing the chdir' do
        expect(IO.read package.staging_path('/etc/init.d/foo') ).to match /start-stop-daemon --start --quiet --pidfile \$PIDFILE --background -d \/fuz --exec/
      end
    end

  end


end
