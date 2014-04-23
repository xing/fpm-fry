require 'fpm/dockery/recipe'
require 'fpm/package'
describe FPM::Dockery::Recipe do

  def build(vars ={}, str)
    b = FPM::Dockery::Recipe::Builder.new(vars)
    b.instance_eval(str)
    return b.recipe
  end

  let(:package) do
    p = FPM::Package.new
    subject.apply(p)
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
      expect(subject.name).to eq "foo"
    end

    it 'has a version' do
      expect(subject.version).to eq '0.2.1'
    end

    it 'applies the name' do
      expect(package.name).to eq 'foo'
    end

    it 'applies the version' do
      expect(package.version).to eq '0.2.1'
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

  context "dependencies" do
    subject do
      build <<RECIPE
depends "foo"
depends "bar", ">=0.0.1"
RECIPE
    end

    it 'works' do
      expect(package.dependencies).to eq(['foo','bar>=0.0.1'])
    end
  end

  context "plugins" do
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

end


