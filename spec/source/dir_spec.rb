require 'fpm/dockery/source/dir'

describe FPM::Dockery::Source::Dir do

  context '#build_cache' do
    let!(:source){
      s = Dir.mktmpdir("fpm-dockery")
      `cd #{s} ; echo "Hello" > "World"`
      s
    }

    after do
      FileUtils.rm_rf(source)
    end

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

end
