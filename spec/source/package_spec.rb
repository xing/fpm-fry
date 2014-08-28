require 'fpm/dockery/source/package'
require 'tempfile'
require 'fileutils'
require 'webmock/rspec'
describe FPM::Dockery::Source::Package do

  let(:tmpdir){
    Dir.mktmpdir("fpm-dockery")
  }

  let(:body){
    body = StringIO.new
    tar = Gem::Package::TarWriter.new(body)
    tar.add_file('foo','0777') do |io|
      io.write("bar")
    end
    body.string
  }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  context '#build_cache' do

    it "fetches a file" do
      stub_request(:get,'http://example/file.tar').to_return(body: "doesn't matter", status: 200)
      src = FPM::Dockery::Source::Package.new("http://example/file.tar")
      src.build_cache(tmpdir)
      expect( File.read(File.join(tmpdir, 'file.tar')) ).to eq("doesn't matter")
    end

    it "follows redirects" do
      stub_request(:get,'http://example/fileA.tar').to_return(status: 302, headers: {'Location' => 'http://example/fileB.tar'} )
      stub_request(:get,'http://example/fileB.tar').to_return(body: "doesn't matter", status: 200)
      src = FPM::Dockery::Source::Package.new("http://example/fileA.tar")
      src.build_cache(tmpdir)
      expect( File.read(File.join(tmpdir, 'fileA.tar')) ).to eq("doesn't matter")
    end

    it "doesn't follow too many redirects" do
      stub_request(:get,'http://example/fileA.tar').to_return(status: 302, headers: {'Location' => 'http://example/fileB.tar'} )
      stub_request(:get,'http://example/fileB.tar').to_return(status: 302, headers: {'Location' => 'http://example/fileA.tar'} )
      src = FPM::Dockery::Source::Package.new("http://example/fileA.tar")
      expect{
        src.build_cache(tmpdir)
      }.to raise_error( FPM::Dockery::Source::CacheFailed, "Too many redirects")
    end

    it "reports missing files" do
      stub_request(:get,'http://example/file.tar').to_return(status: 404)
      src = FPM::Dockery::Source::Package.new("http://example/file.tar")
      expect{
        src.build_cache(tmpdir)
      }.to raise_error(FPM::Dockery::Source::CacheFailed, "Unable to fetch file")
    end

    it "returns checksum as cachekey if present" do
      src = FPM::Dockery::Source::Package.new("http://example/file.tar", checksum: "12345")
      cache = src.build_cache(tmpdir)
      expect( cache.cachekey ).to eq("12345")
    end

    it "fetches file for cachekey if no checksum present" do
      stub_request(:get,'http://example/file.tar').to_return(body: "doesn't matter", status: 200)
      src = FPM::Dockery::Source::Package.new("http://example/file.tar")
      cache = src.build_cache(tmpdir)
      expect( cache.cachekey ).to eq("477c34d98f9e090a4441cf82d2f1f03e64c8eb730e8c1ef39a8595e685d4df65")
    end

  end

  context '#copy_to' do
    let(:destdir){
      Dir.mktmpdir("fpm-dockery")
    }

    after do
      FileUtils.rm_rf(destdir)
    end

    it "untars a file" do
      stub_request(:get,'http://example/file.tar').to_return(body: body, status: 200)
      src = FPM::Dockery::Source::Package.new("http://example/file.tar")
      cache = src.build_cache(tmpdir)
      cache.copy_to(destdir)
      expect( Dir.new(destdir).each.to_a ).to eq ['.','..','foo']
    end

  end

  context '#tar_io' do
    it "untars a file" do
      stub_request(:get,'http://example/file.tar').to_return(body: body, status: 200)
      src = FPM::Dockery::Source::Package.new("http://example/file.tar")
      cache = src.build_cache(tmpdir)
      expect( cache.tar_io.read ).to eq body
    end
  end
end
