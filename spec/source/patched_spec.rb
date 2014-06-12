require 'fpm/dockery/source/patched'
describe FPM::Dockery::Source::Patched do

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
      c
    }

    let(:source){
      s = double('source')
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
      src = FPM::Dockery::Source::Patched.new(source, patches: [ File.join(File.dirname(__FILE__),'..','data','patch.diff')] )
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
