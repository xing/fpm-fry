require 'fpm/fry/source/archive'
require 'tempfile'
require 'fileutils'
require 'webmock/rspec'
require 'rubygems/package'
describe FPM::Fry::Source::Archive do

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
      src = FPM::Fry::Source::Archive.new("http://example/file.tar")
      src.build_cache(tmpdir)
      expect( File.read(File.join(tmpdir, 'file.tar')) ).to eq("doesn't matter")
    end

    it "follows redirects" do
      stub_request(:get,'http://example/fileA.tar').to_return(status: 302, headers: {'Location' => 'http://example/fileB.tar'} )
      stub_request(:get,'http://example/fileB.tar').to_return(body: "doesn't matter", status: 200)
      src = FPM::Fry::Source::Archive.new("http://example/fileA.tar")
      src.build_cache(tmpdir)
      expect( File.read(File.join(tmpdir, 'fileA.tar')) ).to eq("doesn't matter")
    end

    it "doesn't follow too many redirects" do
      stub_request(:get,'http://example/fileA.tar').to_return(status: 302, headers: {'Location' => 'http://example/fileB.tar'} )
      stub_request(:get,'http://example/fileB.tar').to_return(status: 302, headers: {'Location' => 'http://example/fileA.tar'} )
      src = FPM::Fry::Source::Archive.new("http://example/fileA.tar")
      expect{
        src.build_cache(tmpdir)
      }.to raise_error( FPM::Fry::Source::CacheFailed)
    end

    it "reports missing files" do
      stub_request(:get,'http://example/file.tar').to_return(status: 404)
      src = FPM::Fry::Source::Archive.new("http://example/file.tar")
      expect{
        src.build_cache(tmpdir)
      }.to raise_error(FPM::Fry::Source::CacheFailed, "Unable to fetch file"){|e|
        expect(e.data).to eq(
          url: 'http://example/file.tar',
          http_code: 404,
          http_message: ""
        )
      }
    end

    it "reports wrong checksums" do
      stub_request(:get,'http://example/file.tar').to_return(body: "doesn't matter", status: 200)
      src = FPM::Fry::Source::Archive.new("http://example/file.tar", checksum: Digest::SHA256.hexdigest("something else"))
      expect{
        src.build_cache(tmpdir).tar_io
      }.to raise_error(FPM::Fry::Source::CacheFailed, "Checksum failed"){|e|
        expect(e.data).to eq(
          url: 'http://example/file.tar',
          expected: Digest::SHA256.hexdigest("something else"),
          given: Digest::SHA256.hexdigest("doesn't matter")
        )
      }
    end

    it "returns checksum as cachekey if present" do
      src = FPM::Fry::Source::Archive.new("http://example/file.tar", checksum: "477c34d98f9e090a4441cf82d2f1f03e64c8eb730e8c1ef39a8595e685d4df65")
      cache = src.build_cache(tmpdir)
      expect( cache.cachekey ).to eq("477c34d98f9e090a4441cf82d2f1f03e64c8eb730e8c1ef39a8595e685d4df65")
    end

    it "fetches file for cachekey if no checksum present" do
      stub_request(:get,'http://example/file.tar').to_return(body: "doesn't matter", status: 200)
      src = FPM::Fry::Source::Archive.new("http://example/file.tar")
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
        src = FPM::Fry::Source::Archive.new("http://example/file.tar")
        cache = src.build_cache(tmpdir)
        cache.copy_to(destdir)
        expect( Dir.new(destdir).each.to_a ).to contain_exactly('.','..','foo')
      end

    end

    context '#tar_io' do
      it "untars a file" do
        stub_request(:get,'http://example/file.tar').to_return(body: body, status: 200)
        src = FPM::Fry::Source::Archive.new("http://example/file.tar")
        cache = src.build_cache(tmpdir)
        expect( cache.tar_io.read ).to eq body
      end

      it "untars a gz file" do
        gzbody = StringIO.new
        gz = Zlib::GzipWriter.new( gzbody )
        gz.write(body)
        gz.close
        stub_request(:get,'http://example/file.tar.gz').to_return(body: gzbody.string, status: 200)
        src = FPM::Fry::Source::Archive.new("http://example/file.tar.gz")
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
        src = FPM::Fry::Source::Archive.new("http://example/file.zip")
        cache = src.build_cache(tmpdir)
        io = cache.tar_io
        begin
          rd = FPM::Fry::Tar::Reader.new(IOFilter.new(io))
          files = Hash[ rd.each.map{|e| [e.header.name, e.read] } ]
          expect(files.size).to eq(2)
          expect(files['./foo']).to eq "bar"
        ensure
          io.close
        end
      end

      it "doesn't unzip twice" do
        stub_request(:get,'http://example/file.zip').to_return(body: zipfile, status: 200)
        src = FPM::Fry::Source::Archive.new("http://example/file.zip")
        cache = src.build_cache(tmpdir)
        cache.tar_io.close

        src = FPM::Fry::Source::Archive.new("http://example/file.zip")
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
        src = FPM::Fry::Source::Archive.new('http://example/dir/plainfile.bin')
        cache = src.build_cache(tmpdir)
        io = cache.tar_io
        begin
          rd = FPM::Fry::Tar::Reader.new(IOFilter.new(io))
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
        src = FPM::Fry::Source::Archive.new('http://example/dir/plainfile.bin')
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
        src = FPM::Fry::Source::Archive.new("http://example/file.tar.bz2")
        cache = src.build_cache(tmpdir)
        io = cache.tar_io
        begin
          rd = FPM::Fry::Tar::Reader.new(IOFilter.new(io))
          files = Hash[ rd.each.map{|e| [e.header.name, e.read] } ]
          expect(files).to eq 'foo' => 'bar'
        ensure
          io.close
        end
      end

    end
  end

  context 'with an unknown extension' do

    it 'raises an error' do
      expect{
        FPM::Fry::Source::Archive.new("http://example/file.unknown")
      }.to raise_error(FPM::Fry::Source::Archive::UnknownArchiveType,"Unknown archive type"){|e|
        expect(e.data).to include(
          url: "http://example/file.unknown",
          known_extensions: include(".tar",".tar.gz")
        )
      }
    end

  end

  describe '#prefix' do

    context 'with a simple tar file' do
      it "returns an empty string" do
        stub_request(:get,'http://example/file.tar').to_return(body: body, status: 200)
        src = FPM::Fry::Source::Archive.new("http://example/file.tar")
        cache = src.build_cache(tmpdir)
        expect( cache.prefix ).to eq ''
      end
    end

    context 'with a more complex tar file' do

      let(:body){
        body = StringIO.new
        tar = Gem::Package::TarWriter.new(body)
        tar.mkdir('bar/','0777')
        tar.add_file('bar/foo','0777') do |io|
          io.write("bar")
        end
        tar.mkdir('bar/baz','0777')
        tar.add_file('bar/baz/blub','0777') do |io|
          io.write("bar")
        end
        body.string
      }

      it "returns the prefix string" do
        stub_request(:get,'http://example/file.tar').to_return(body: body, status: 200)
        src = FPM::Fry::Source::Archive.new("http://example/file.tar")
        cache = src.build_cache(tmpdir)
        expect( cache.prefix ).to eq 'bar'
      end
    end

    context 'with a simple zip file' do
      let(:body) do
        outfile = File.join(tmpdir,'zipfile.zip')
        Dir.chdir(tmpdir) do
          IO.write('foo', 'bar')
          system('zip',outfile,'foo', out: '/dev/null')
        end
        IO.read(outfile)
      end

      it "returns an empty string" do
        stub_request(:get,'http://example/file.zip').to_return(body: body, status: 200)
        src = FPM::Fry::Source::Archive.new("http://example/file.zip")
        cache = src.build_cache(tmpdir)
        expect( cache.prefix ).to eq ''
      end
    end

    context 'with a more complex zip file' do
      let(:body) do
        outfile = File.join(tmpdir,'zipfile.zip')
        Dir.chdir(tmpdir) do
          Dir.mkdir('foo')
          Dir.mkdir('foo/bar')
          Dir.mkdir('foo/bar/baz')
          IO.write('foo/bar/fuz', 'bar')
          system('zip','-r',outfile,'foo', out: '/dev/null')
        end
        IO.read(outfile)
      end

      it "returns the prefix string" do
        stub_request(:get,'http://example/file.zip').to_return(body: body, status: 200)
        src = FPM::Fry::Source::Archive.new("http://example/file.zip")
        cache = src.build_cache(tmpdir)
        expect( cache.prefix ).to eq 'foo/bar'
      end
    end


  end
end
