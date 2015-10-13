require 'fpm/fry/detector'
require 'rubygems/package/tar_header'
describe FPM::Fry::Detector::Container do

  let(:client){
    cl = double(:client)
    allow(cl).to receive(:read){ raise FPM::Fry::Client::FileNotFound }
    cl
  }

  subject{
    FPM::Fry::Detector::Container.new(client, 'doesntmatter')
  }

  class TarEntryMock < StringIO
    attr :header

    def initialize(string, options = {})
      super(string)
      options = {name: "", size: 0, prefix: "", mode: 0777}.merge(options)
      @header = Gem::Package::TarHeader.new(options)
    end

  end

  it 'reads /etc/lsb-release' do
    expect(client).to receive(:read).with(
                        'doesntmatter','/etc/lsb-release'
                      ).and_yield(TarEntryMock.new(<<LSB))
DISTRIB_ID=foo
Random trash
DISTRIB_RELEASE=1234
LSB
    expect(subject.detect!).to be true
    expect(subject.distribution).to eq('foo')
    expect(subject.version).to eq('1234')
  end

  it 'reads /etc/debian_version' do
    expect(client).to receive(:read).with(
                        'doesntmatter','/etc/debian_version'
                      ).and_yield(TarEntryMock.new(<<LSB))
6.0.5
LSB
    expect(subject.detect!).to be true
    expect(subject.distribution).to eq('debian')
    expect(subject.version).to eq('6.0.5')
  end

  it 'reads /etc/redhat-release' do
    expect(client).to receive(:read).with(
                        'doesntmatter','/etc/redhat-release'
                      ).and_yield(TarEntryMock.new(<<LSB))
Foobar release 1.33.7
LSB
    expect(subject.detect!).to be true
    expect(subject.distribution).to eq('foobar')
    expect(subject.version).to eq('1.33.7')
  end

  it 'reads linked /etc/redhat-release' do
    expect(client).to receive(:read).with(
                        'doesntmatter','/etc/redhat-release'
                      ).and_yield(TarEntryMock.new('', typeflag: "2", linkname: "centos-release" ))
    expect(client).to receive(:read).with(
                        'doesntmatter','/etc/centos-release'
                      ).and_yield(TarEntryMock.new(<<LSB))
Foobar release 1.33.7
LSB
    expect(subject.detect!).to be true
    expect(subject.distribution).to eq('foobar')
    expect(subject.version).to eq('1.33.7')
  end
end

describe FPM::Fry::Detector::Image do

  let(:client){
    cl = double(:client)
    allow(cl).to receive(:url){|*args| args.join('/') }
    cl
  }

  let(:container_detector){
    double(:container_detector)
  }

  let(:factory){
    f = double(:factory)
    allow(f).to receive(:new).and_return(container_detector)
    f
  }

  subject{
    FPM::Fry::Detector::Image.new(client, 'doesntmatter', factory)
  }

  it "creates an image an delegates to its factory" do
    expect(client).to receive(:post).and_return(double(body: '{"Id":"deadbeef"}'))
    expect(client).to receive(:delete).with(path: 'containers/deadbeef')
    expect(container_detector).to receive(:detect!).and_return(true)
    expect(container_detector).to receive(:distribution).and_return("foo")
    expect(container_detector).to receive(:version).and_return("1.2.3")
    expect( subject.detect! ).to be true
  end

end

