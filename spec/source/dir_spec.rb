require 'fpm/dockery/source/dir'

describe FPM::Dockery::Source::Dir do

  let!(:source){
    s = Dir.mktmpdir("fpm-dockery")
    `cd #{s} ; echo "Hello" > "World"`
    s
  }

  after do
    FileUtils.rm_rf(source)
  end

  context '#build_cache' do
    it "tars a dir" do
      src = FPM::Dockery::Source::Dir.new(source)
      cache = src.build_cache(double('tmpdir'))
      io = cache.tar_io
      begin
        rd = Gem::Package::TarReader.new(IOFilter.new(io))
        files = rd.each.select{|e| e.header.name == "./World" }
        expect(files.size).to eq(1)
      ensure
        io.close
      end
    end

  end

  context '#cachekey' do
    it "works somewhat" do
      src = FPM::Dockery::Source::Dir.new(source)
      cache = src.build_cache(double('tmpdir'))
      expect(cache.cachekey).to eq(Digest::SHA2.hexdigest(cache.tar_io.read))
    end
  end

  context '#copy_to' do

    let(:target){
      Dir.mktmpdir("fpm-dockery")
    }

    after do
      FileUtils.rm_rf(target)
    end

    it 'copies all contents to the given destination' do
      src = FPM::Dockery::Source::Dir.new(source)
      cache = src.build_cache(double('tmpdir'))
      cache.copy_to(target)
      expect(Dir.new(target).entries.sort).to eq [".","..","World"]
      expect(IO.read(File.join(target,"World"))).to eq "Hello\n"
    end

  end

  context 'with relative paths' do
    it "works somewhat" do
      base = File.dirname(source)
      src = Dir.chdir base do
        FPM::Dockery::Source::Dir.new(File.basename(source))
      end
      cache = src.build_cache(double('tmpdir'))
      io = cache.tar_io
      begin
        rd = Gem::Package::TarReader.new(IOFilter.new(io))
        files = rd.each.select{|e| e.header.name == "./World" }
        expect(files.size).to eq(1)
      ensure
        io.close
      end
    end
  end

end
