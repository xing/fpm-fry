require 'tempfile'
require 'fileutils'
require 'fpm/dockery/source/git'
require 'rubygems/package/tar_reader'
describe FPM::Dockery::Source::Git do

  context '#build_cache' do
    let(:tmpdir){
      Dir.mktmpdir("fpm-dockery")
    }

    let!(:source){
      s = Dir.mktmpdir("fpm-dockery")
      `cd #{s} ; git init ; echo "Hello" > "World" ; git add . ; git -c user.name=Example -c user.email=example@dockery.git commit -m test "--date=2000-01-01T00:00:00 +0000"`
      s
    }

    after do
      FileUtils.rm_rf(tmpdir)
      FileUtils.rm_rf(source)
    end

    class IOFilter < Struct.new(:io)
      def pos
        0
      end

      def read(*args)
        return io.read(*args)
      end

      def eof?
        io.eof?
      end
    end

    it "clones a repo" do
      src = FPM::Dockery::Source::Git.new(source)
      cache = src.build_cache(tmpdir)
      io = cache.tar_io
      begin
        rd = Gem::Package::TarReader.new(IOFilter.new(io))
        files = rd.each.select{|e| e.header.name == "World" }
        expect(files.size).to eq(1)
      ensure
        io.close
      end
    end

    it "raises for missing revs" do
      src = FPM::Dockery::Source::Git.new(source, branch: 'missing')
      expect{
        cache = src.build_cache(tmpdir)
      }.to raise_error(/Failed to fetch/)
    end

  end

end
