require 'fpm/dockery/source/patched'
require 'digest'
describe FPM::Dockery::Source::Patched do

  let(:patches){
    [ File.expand_path(File.join(File.dirname(__FILE__),'..','data','patch.diff')) ]
  }

  context '#build_cache' do

    let(:tmpdir){
      Dir.mktmpdir('fpm-dockery')
    }

    let(:cache){
      c = double('cache')
      allow(c).to receive(:tar_io){
        sio = StringIO.new
        tw = ::Gem::Package::TarWriter.new(sio)
        tw.add_file('World',0755) do |io|
          io.write("Hello\n")
        end
        sio.rewind
        sio
      }
      allow(c).to receive(:cachekey){
        Digest::SHA1.hexdigest("World\x00Hello\n")
      }
      c
    }

    let(:source){
      s = double('source')
      allow(s).to receive(:logger){ Cabin::Channel.get }
      allow(s).to receive(:build_cache){|_| cache }
      s
    }

    after do
      FileUtils.rm_rf(tmpdir)
    end

    it "just passes if no patch is present" do
      src = FPM::Dockery::Source::Patched.new(source)
      cache = src.build_cache(tmpdir)
      io = cache.tar_io
      begin
        rd = Gem::Package::TarReader.new(IOFilter.new(io))
        files = Hash[ rd.each.map{|e| [e.header.name, e.read] } ]
        expect(files.size).to eq(2)
        expect(files['./World']).to eq "Hello\n"
      ensure
        io.close
      end
    end

    it "applies given patches" do
      src = FPM::Dockery::Source::Patched.new(source, patches: patches )
      cache = src.build_cache(tmpdir)
      io = cache.tar_io
      begin
        rd = Gem::Package::TarReader.new(IOFilter.new(io))
        files = Hash[ rd.each.map{|e| [e.header.name, e.read] } ]
        expect(files.size).to eq(2)
        expect(files['./World']).to eq "Olla\n"
      ensure
        io.close
      end
    end

    it "applies given patches with chdir" do
      allow(cache).to receive(:tar_io){
        sio = StringIO.new
        tw = ::Gem::Package::TarWriter.new(sio)
        tw.add_file('World',0755) do |io|
          io.write("Hello\n")
        end
        tw.add_file('foo/World',0755) do |io|
          io.write("Hello\n")
        end
        sio.rewind
        sio
      }
      src = FPM::Dockery::Source::Patched.new(source,
                                              patches: [
                                                file: patches[0], chdir: 'foo'
                                              ] )
      cache = src.build_cache(tmpdir)
      io = cache.tar_io
      begin
        rd = Gem::Package::TarReader.new(IOFilter.new(io))
        files = Hash[ rd.each.map{|e| [e.header.name, e.read] } ]
        expect(files.size).to eq(4)
        expect(files['./World']).to eq "Hello\n"
        expect(files['./foo/World']).to eq "Olla\n"
      ensure
        io.close
      end
    end

    it "returns the correct cachekey" do
      src = FPM::Dockery::Source::Patched.new(source, patches: patches )
      cache = src.build_cache(tmpdir)
      expect( cache.cachekey ).to eq Digest::SHA2.hexdigest(cache.inner.cachekey + "\x00" + IO.read(src.patches[0][:file]) + "\x00")
    end

    it "doesn't create colliding caches" do
      src  = FPM::Dockery::Source::Patched.new(source, patches: patches )
      cache = src.build_cache(tmpdir)
      io = cache.tar_io
      begin
        rd = Gem::Package::TarReader.new(IOFilter.new(io))
        files = Hash[ rd.each.map{|e| [e.header.name, e.read] } ]
        expect(files.size).to eq(2)
        expect(files['./World']).to eq "Olla\n"
      ensure
        io.close
      end

      src = FPM::Dockery::Source::Patched.new(source, patches: [File.expand_path(File.join(File.dirname(__FILE__),'..','data','patch2.diff'))] )
      cache = src.build_cache(tmpdir)
      io = cache.tar_io
      begin
        rd = Gem::Package::TarReader.new(IOFilter.new(io))
        files = Hash[ rd.each.map{|e| [e.header.name, e.read] } ]
        expect(files.size).to eq(2)
        expect(files['./World']).to eq "Ciao\n"
      ensure
        io.close
      end

      src  = FPM::Dockery::Source::Patched.new(source, patches: patches )
      cache = src.build_cache(tmpdir)
      io = cache.tar_io
      begin
        rd = Gem::Package::TarReader.new(IOFilter.new(io))
        files = Hash[ rd.each.map{|e| [e.header.name, e.read] } ]
        expect(files.size).to eq(2)
        expect(files['./World']).to eq "Olla\n"
      ensure
        io.close
      end
    end

    context 'with #copy_to' do
      before do
        allow(cache).to receive(:copy_to) do |dst|
          File.open(File.join(dst,'World'),'w',0755) do |f|
            f.write("Hello\n")
          end
        end
        expect(cache).not_to receive(:tar_io)
      end

      it "applies given patches" do
        src = FPM::Dockery::Source::Patched.new(source, patches: patches )
        cache = src.build_cache(tmpdir)
        io = cache.tar_io
        begin
          rd = Gem::Package::TarReader.new(IOFilter.new(io))
          files = Hash[ rd.each.map{|e| [e.header.name, e.read] } ]
          expect(files.size).to eq(2)
          expect(files['./World']).to eq "Olla\n"
        ensure
          io.close
        end
      end

    end

  end

  context '#decorate' do

    let(:source){ double("source") }

    it 'just passes if nothing is configured' do
      expect(FPM::Dockery::Source::Patched.decorate({}){source}).to be source
    end

    it 'just passes if the patches list is empty' do
      expect(FPM::Dockery::Source::Patched.decorate(patches: []){source}).to be source
    end
    it 'decorates if the list is not empty' do
      expect(FPM::Dockery::Source::Patched.decorate(patches: patches){source}).to be_a FPM::Dockery::Source::Patched
    end
    it 'passes the patch file list' do
      expect(FPM::Dockery::Source::Patched.decorate(patches: patches){source}.patches).to eq [{file:patches[0]}]
    end
  end
end
