require 'fpm/fry/recipe'
require 'fpm/fry/recipe/builder'
require 'fpm/package'
describe FPM::Fry::Recipe do

  def build(vars ={}, str)
    b = FPM::Fry::Recipe::Builder.new(vars)
    b.instance_eval(str)
    return b.recipe
  end

  let(:package) do
    p = FPM::Package.new
    subject.packages[0].apply(p)
    p
  end

  context "basic attributes" do
    subject do
      build <<RECIPE
name "foo"
version "0.2.1"
RECIPE
    end

    it 'has a name' do
      expect(package.name).to eq "foo"
    end

    it 'has a version' do
      expect(package.version).to eq '0.2.1'
    end

    it 'applies the name' do
      expect(package.name).to eq 'foo'
    end

    it 'applies the version' do
      expect(package.version).to eq '0.2.1'
    end
  end

  context 'bash' do

    context 'with just code' do
      subject do
        build <<RECIPE
bash 'just code >> file'
RECIPE
      end

      it 'creates a bash step' do
        expect(subject.steps.map(&:to_s)).to eq ['just code >> file']
      end
    end

    context 'with a name' do
      subject do
        build <<RECIPE
bash 'a name', 'with more "code"'
RECIPE
      end

      it 'creates a named step' do
        expect(subject.steps.map(&:to_s)).to eq ['with more "code"']
      end
    end
  end

  context 'before_build' do

    context 'inserts bash scripts into the before_build_steps section' do
      subject do 
        build <<RECIPE
bash 'before'
before_build do
  bash 'inside'
end
bash 'after'
RECIPE
      end

      it 'places inner bash steps in before_build_steps' do
        expect(subject.before_build_steps.map(&:to_s)).to eq ['inside']
      end

      it 'places surrounding bash steps in steps' do
        expect(subject.steps.map(&:to_s)).to eq ['before','after']
      end
    end

  end

  context 'before_dependencies' do

    context 'inserts bash scripts into the before_dependencies_steps section' do
      subject do
        build <<RECIPE
bash 'before'
before_dependencies do
  bash 'inside'
end
bash 'after'
RECIPE
      end

      it 'places inner bash steps in before_dependencies_steps' do
        expect(subject.before_dependencies_steps.map(&:to_s)).to eq ['inside']
      end

      it 'places surrounding bash steps in steps' do
        expect(subject.steps.map(&:to_s)).to eq ['before','after']
      end
    end

  end


  context "scripts" do
    subject do
      build <<RECIPE
before_install "before install"
RECIPE
    end

    it 'support setting before_install' do
      expect(package.scripts).to eq({before_install: "before install"})
    end
  end

  context "relations" do
    subject do
      build <<RECIPE
depends "foo"
depends "bar", ">=0.0.1"
depends "blub", "0.3.1"
conflicts "zub"
provides "fub"
replaces "zof"
RECIPE
    end

    it 'has correct dependencies' do
      expect(package.dependencies).to eq(['foo','bar >= 0.0.1', 'blub = 0.3.1'])
    end

    it 'has correct conflicts' do
      expect(package.conflicts).to eq(['zub'])
    end

    it 'has correct provides' do
      expect(package.provides).to eq(['fub'])
    end

    it 'has correct replaces' do
      expect(package.replaces).to eq(['zof'])
    end

    context 'with multiple constraints' do
      subject do
        build <<RECIPE
depends "bar", ">= 0.0.1, << 0.0.2"
RECIPE
      end

      it 'has multiple dependencies' do
        expect(package.dependencies).to eq(['bar >= 0.0.1', 'bar << 0.0.2'])
      end
    end

    context 'with a duplicate dependency' do
      it 'raises an error' do
        expect{
          build <<RECIPE
depends 'x'
depends 'x'
RECIPE
        }.to raise_error(FPM::Fry::Recipe::Error, "duplicate dependency"){|e| expect(e.data).to eq package: 'x' }
      end
    end

    context 'with a duplicate conflict' do
      it 'raises an error' do
        expect{
          build <<RECIPE
conflicts 'x'
conflicts 'x'
RECIPE
        }.to raise_error(FPM::Fry::Recipe::Error, "duplicate conflict"){|e| expect(e.data).to eq package: 'x' }
      end
    end

    context 'with a dependency duplicating a conflict' do
      it 'raises an error' do
        expect{
          build <<RECIPE
conflicts 'x'
depends 'x'
RECIPE
        }.to raise_error(FPM::Fry::Recipe::Error,"depending package is already a conflicting package"){|e| expect(e.data).to eq package: 'x' }
      end
    end

    context 'with a conflict duplicating a dependency' do
      it 'raises an error' do
        expect{
          build <<RECIPE
depends 'x'
conflicts 'x'
RECIPE
        }.to raise_error(FPM::Fry::Recipe::Error,"conflicting package is already a dependency"){|e| expect(e.data).to eq package: 'x' }
      end
    end
  end

  context "plugins" do
    context 'simple example' do
      subject do
        build( {distribution: "ubuntu"}, <<RECIPE)
plugin "platforms"

platforms [:ubuntu] do
  depends "ubuntu"
end

platforms [:centos] do
  depends "centos"
end
RECIPE
      end

      it 'works' do
        expect(package.dependencies).to eq(['ubuntu'])
      end
    end

    context 'simple module with extra args' do
      subject do
        build( {distribution: "ubuntu"}, <<RECIPE)
plugin "platforms","foo"
RECIPE
      end

      it "raises an error" do
        expect{ subject }.to raise_error(ArgumentError, /Simple plugins can't accept additional arguments/)
      end
    end

    context 'simple module with extra block' do
      subject do
        build( {distribution: "ubuntu"}, <<RECIPE)
plugin "platforms" do
end
RECIPE
      end

      it "raises an error" do
        expect{ subject }.to raise_error(ArgumentError, /Simple plugins can't accept additional arguments/)
      end
    end


  end

  context 'source type guessing' do

    subject{ FPM::Fry::Recipe::Builder.new({}) }

    {
      'http://foo.bar/baz.tar.gz' => FPM::Fry::Source::Archive,
      'http://foo.bar/baz.git'    => FPM::Fry::Source::Git,
      'git@foo.bar:baz/baz.git'   => FPM::Fry::Source::Git,
      'git+ssh://foo.bar/baz'     => FPM::Fry::Source::Git,
      'https://git.foo.bar/baz'   => FPM::Fry::Source::Git,
      '/foo/bar'                  => FPM::Fry::Source::Dir,
      './foo/bar'                 => FPM::Fry::Source::Dir,
      'file://foo/bar'            => FPM::Fry::Source::Dir
    }.each do |url, klass|
      it "map #{url} to #{klass}" do
        expect( subject.send(:guess_source,url) ).to eq klass
      end
    end

    it 'raises an error when nothing matches' do
      expect{ subject.send(:guess_source,'foo://bar') }.to raise_error(FPM::Fry::Recipe::Error, %r!No source provider found for foo://bar.!)
    end

  end

  describe '#load_file' do
    let(:tmpdir){
      Dir.mktmpdir("fpm-fry")
    }
    after(:each) do
      FileUtils.rm_rf(tmpdir)
    end

    context 'working directory' do

      it "is switched to the recipes basedir" do
        IO.write(File.join(tmpdir,'recipe.rb'),'variables[:probe] << Dir.pwd')
        builder = FPM::Fry::Recipe::Builder.new(probe: [])
        builder.load_file(File.join(tmpdir,'recipe.rb'))
        expect(builder.variables[:probe][0]).to eq(tmpdir)
      end

    end
  end

  describe '#lint' do

    context 'with broken scripts' do
      subject do
        build( {distribution: "ubuntu"}, <<RECIPE)
name 'foo'
after_install '#!/bin/bash
if [ $1 = "configure" ] ; then
  broken'
RECIPE
      end

      it 'reports the scripts' do
        expect(subject.lint).to eq ["after_install script is not valid /bin/bash code: /bin/bash: line 4: syntax error: unexpected end of file"]
      end

    end
  end
end

