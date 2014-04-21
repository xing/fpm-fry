require 'fpm/dockery/source/package'
require 'tempfile'
require 'fileutils'
require 'webmock/rspec'
describe FPM::Dockery::Source::Package do

  context '#build_cache' do

    let(:tmpdir){
      Dir.mktmpdir("fpm-dockery")
    }

    after do
      FileUtils.rm_rf(tmpdir)
    end

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

  end
end
