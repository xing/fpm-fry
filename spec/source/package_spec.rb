require 'fpm/fry/source/package'
require 'tempfile'
require 'fileutils'
require 'webmock/rspec'
require 'rubygems/package'
describe FPM::Fry::Source::Package do

  let(:tmpdir){
    Dir.mktmpdir("fpm-fry")
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
      src = FPM::Fry::Source::Package.new("http://example/file.tar")
      src.build_cache(tmpdir)
      expect( File.read(File.join(tmpdir, 'file.tar')) ).to eq("doesn't matter")
    end

    it "follows redirects" do
      stub_request(:get,'http://example/fileA.tar').to_return(status: 302, headers: {'Location' => 'http://example/fileB.tar'} )
      stub_request(:get,'http://example/fileB.tar').to_return(body: "doesn't matter", status: 200)
      src = FPM::Fry::Source::Package.new("http://example/fileA.tar")
      src.build_cache(tmpdir)
      expect( File.read(File.join(tmpdir, 'fileA.tar')) ).to eq("doesn't matter")
    end

    it "doesn't follow too many redirects" do
      stub_request(:get,'http://example/fileA.tar').to_return(status: 302, headers: {'Location' => 'http://example/fileB.tar'} )
      stub_request(:get,'http://example/fileB.tar').to_return(status: 302, headers: {'Location' => 'http://example/fileA.tar'} )
      src = FPM::Fry::Source::Package.new("http://example/fileA.tar")
      expect{
        src.build_cache(tmpdir)
      }.to raise_error( FPM::Fry::Source::CacheFailed, "Too many redirects")
    end

    it "reports missing files" do
      stub_request(:get,'http://example/file.tar').to_return(status: 404)
      src = FPM::Fry::Source::Package.new("http://example/file.tar")
      expect{
        src.build_cache(tmpdir)
      }.to raise_error(FPM::Fry::Source::CacheFailed, "Unable to fetch file")
    end

    it "returns checksum as cachekey if present" do
      src = FPM::Fry::Source::Package.new("http://example/file.tar", checksum: "477c34d98f9e090a4441cf82d2f1f03e64c8eb730e8c1ef39a8595e685d4df65")
      cache = src.build_cache(tmpdir)
      expect( cache.cachekey ).to eq("477c34d98f9e090a4441cf82d2f1f03e64c8eb730e8c1ef39a8595e685d4df65")
    end

    it "fetches file for cachekey if no checksum present" do
      stub_request(:get,'http://example/file.tar').to_return(body: "doesn't matter", status: 200)
      src = FPM::Fry::Source::Package.new("http://example/file.tar")
      cache = src.build_cache(tmpdir)
      expect( cache.cachekey ).to eq("477c34d98f9e090a4441cf82d2f1f03e64c8eb730e8c1ef39a8595e685d4df65")
    end

  end

  context 'with a tar file' do
    context '#copy_to' do
      let(:destdir){
        Dir.mktmpdir("fpm-fry")
      }

      after do
        FileUtils.rm_rf(destdir)
      end

      it "untars a file" do
        stub_request(:get,'http://example/file.tar').to_return(body: body, status: 200)
        src = FPM::Fry::Source::Package.new("http://example/file.tar")
        cache = src.build_cache(tmpdir)
        cache.copy_to(destdir)
        expect( Dir.new(destdir).each.to_a ).to eq ['.','..','foo']
      end

    end

    context '#tar_io' do
      it "untars a file" do
        stub_request(:get,'http://example/file.tar').to_return(body: body, status: 200)
        src = FPM::Fry::Source::Package.new("http://example/file.tar")
        cache = src.build_cache(tmpdir)
        expect( cache.tar_io.read ).to eq body
      end

      it "untars a gz file" do
        gzbody = StringIO.new
        gz = Zlib::GzipWriter.new( gzbody )
        gz.write(body)
        gz.close
        stub_request(:get,'http://example/file.tar.gz').to_return(body: gzbody.string, status: 200)
        src = FPM::Fry::Source::Package.new("http://example/file.tar.gz")
        cache = src.build_cache(tmpdir)
        expect( cache.tar_io.read ).to eq body
      end
    end
  end

  context 'with a zip file' do

    let(:zipfile) do
      outfile = File.join(tmpdir,'zipfile.zip')
      Dir.chdir(tmpdir) do
        IO.write('foo', 'bar')
        system('zip',outfile,'foo', out: '/dev/null')
      end
      IO.read(outfile)
    end

    context '#tar_io' do
      it "unzips a zip file" do
        stub_request(:get,'http://example/file.zip').to_return(body: zipfile, status: 200)
        src = FPM::Fry::Source::Package.new("http://example/file.zip")
        cache = src.build_cache(tmpdir)
        io = cache.tar_io
        begin
          rd = Gem::Package::TarReader.new(IOFilter.new(io))
          files = Hash[ rd.each.map{|e| [e.header.name, e.read] } ]
          expect(files.size).to eq(2)
          expect(files['./foo']).to eq "bar"
        ensure
          io.close
        end
      end

      it "doesn't unzip twice" do
        stub_request(:get,'http://example/file.zip').to_return(body: zipfile, status: 200)
        src = FPM::Fry::Source::Package.new("http://example/file.zip")
        cache = src.build_cache(tmpdir)
        cache.tar_io.close

        src = FPM::Fry::Source::Package.new("http://example/file.zip")
        cache = src.build_cache(tmpdir)
        expect(cache).not_to receive(:copy_to)
        cache.tar_io.close
      end
    end
  end

  context 'with a plain file' do

    context '#tar_io' do
      it "tars the file" do
        stub_request(:get,'http://example/dir/plainfile.bin').to_return(body: "bar", status: 200)
        src = FPM::Fry::Source::Package.new('http://example/dir/plainfile.bin')
        cache = src.build_cache(tmpdir)
        io = cache.tar_io
        begin
          rd = Gem::Package::TarReader.new(IOFilter.new(io))
          files = Hash[ rd.each.map{|e| [e.header.name, e.read] } ]
          expect(files).to eq('plainfile.bin' => 'bar')
        ensure
          io.close
        end
      end

    end

    context '#copy_to' do
      let(:destdir){
        Dir.mktmpdir("fpm-fry")
      }

      after do
        FileUtils.rm_rf(destdir)
      end

      it "copies a file" do
        stub_request(:get,'http://example/dir/plainfile.bin').to_return(body: "bar", status: 200)
        src = FPM::Fry::Source::Package.new('http://example/dir/plainfile.bin')
        cache = src.build_cache(tmpdir)
        cache.copy_to(destdir)
        expect( Dir.new(destdir).each.to_a ).to contain_exactly '.','..','plainfile.bin'
      end

    end
  end

  context 'with a tar.bz2 file' do

    let(:tarfile) do
      outfile = File.join(tmpdir,'file.tar.bz2')
      Dir.chdir(tmpdir) do
        IO.write('foo', 'bar')
        system('tar','-cjf',outfile,'foo', out: '/dev/null')
      end
      IO.read(outfile)
    end

    context '#tar_io' do
      it "untars a tar file" do
        stub_request(:get,'http://example/file.tar.bz2').to_return(body: tarfile, status: 200)
        src = FPM::Fry::Source::Package.new("http://example/file.tar.bz2")
        cache = src.build_cache(tmpdir)
        io = cache.tar_io
        begin
          rd = Gem::Package::TarReader.new(IOFilter.new(io))
          files = Hash[ rd.each.map{|e| [e.header.name, e.read] } ]
          expect(files).to eq 'foo' => 'bar'
        ensure
          io.close
        end
      end

    end
  end
end
