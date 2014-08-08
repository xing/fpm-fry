require 'tempfile'
require 'fileutils'
require 'fpm/dockery/source/git'
require 'rubygems/package/tar_reader'
describe FPM::Dockery::Source::Git do

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

  context '#build_cache' do
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

  context '#copy_to' do

    let(:target){
      Dir.mktmpdir("fpm-dockery")
    }

    after do
      FileUtils.rm_rf(target)
    end

    it 'copies all contents to the given destination' do
      src = FPM::Dockery::Source::Git.new(source)
      cache = src.build_cache(tmpdir)
      cache.copy_to(target)
      expect(Dir.new(target).entries.sort).to eq [".","..","World"]
      expect(IO.read(File.join(target,"World"))).to eq "Hello\n"
    end

  end

end
