require 'fpm/dockery/client'
require 'webmock/rspec'
require 'rubygems/package'
require 'tempfile'
require 'fileutils'
describe FPM::Dockery::Client do

  subject{
    FPM::Dockery::Client.new(docker_url: 'http://dock.er')
  }

  before(:each) do
    stub_request(:get, "http://dock.er/version").
      to_return(:status => 200, :body =>'{"ApiVersion":"1.9"}', :headers => {})
  end

  describe '#read' do
    context 'existing file' do
      let(:body){
        body = StringIO.new
        tar = Gem::Package::TarWriter.new(body)
        tar.add_file('foo','0777') do |io|
          io.write("bar")
        end
        body.rewind
        body
      }

      it 'is yielded' do
        stub_request(:post,'http://dock.er/v1.9/containers/deadbeef/copy').to_return(status: 200, body: body.string)
        expect{|yld|
          subject.read('deadbeef','foo', &yld)
        }.to yield_with_args(Gem::Package::TarReader::Entry)
      end
    end

    context 'missing file' do
      it 'raises' do
        stub_request(:post,'http://dock.er/v1.9/containers/deadbeef/copy').to_return(status: 500)
        expect{
          subject.read('deadbeef','foo'){}
        }.to raise_error(FPM::Dockery::Client::FileNotFound)
      end
    end
  end

  describe '#copy' do
    context 'a simple file' do
      let(:body){
        body = StringIO.new
        tar = Gem::Package::TarWriter.new(body)
        tar.add_file('foo','0777') do |io|
          io.write("bar")
        end
        body.rewind
        body
      }

      let!(:tmpdir){
        Dir.mktmpdir('fpm-dockery')
      }

      after(:each) do
        FileUtils.rm_rf(tmpdir)
      end

      it 'is copied' do
        stub_request(:post,'http://dock.er/v1.9/containers/deadbeef/copy').to_return(status: 200, body: body.string)
        subject.copy('deadbeef','foo', { 'foo' => tmpdir + '/foo' })
        expect( File.read(File.join(tmpdir,'foo')) ).to eq('bar')
      end
    end

    context 'a folder with a symlink' do
      let(:body){
        body = StringIO.new
        body.write Gem::Package::TarHeader.new(
          name: 'foo', prefix: '', mode: '0777',
          size: 0, mtime: Time.now, typeflag: '5'
        )
        body.write Gem::Package::TarHeader.new(
          name: 'a', prefix: 'foo', mode: '0777',
          size: 0, mtime: Time.now, typeflag: '2',
          linkname: 'b'
        )
        body.write( "\0" * 1024 )
        body.rewind
        body
      }

      let!(:tmpdir){
        Dir.mktmpdir('fpm-dockery')
      }

      after(:each) do
        FileUtils.rm_rf(tmpdir)
      end

      it 'is copied' do
        stub_request(:post,'http://dock.er/v1.9/containers/deadbeef/copy').to_return(status: 200, body: body.string)
        subject.copy('deadbeef','foo', {'foo' => tmpdir + '/foo' , 'foo/a' => tmpdir + '/foo/a'})
        expect( File.readlink(File.join(tmpdir,'foo/a')) ).to eq('b')
      end
    end
  end
end
