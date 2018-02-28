require 'tempfile'
require 'fileutils'
require 'fpm/fry/source/git'
require 'rubygems/package/tar_reader'
describe FPM::Fry::Source::Git do

  let(:tmpdir){
    Dir.mktmpdir("fpm-fry")
  }

  let!(:source){
    s = Dir.mktmpdir("fpm-fry")
    `cd #{s} ; git init ; echo "Hello" > "World" ; git add . ;
    git -c user.name=Example -c user.email=example@fry.git commit -m test "--date=2000-01-01T00:00:00 +0000"`
    s
  }

  after do
    FileUtils.rm_rf(tmpdir)
    FileUtils.rm_rf(source)
  end

  context '#build_cache' do
    it "clones a repo" do
      src = FPM::Fry::Source::Git.new(source)
      cache = src.build_cache(tmpdir)
      io = cache.tar_io
      begin
        rd = FPM::Fry::Tar::Reader.new(IOFilter.new(io))
        files = rd.each.select{|e| e.header.name == "World" }
        expect(files.size).to eq(1)
      ensure
        io.close
      end
    end

    it "raises for missing revs" do
      src = FPM::Fry::Source::Git.new(source, branch: 'missing')
      expect{
        cache = src.build_cache(tmpdir)
      }.to raise_error(FPM::Fry::Source::CacheFailed, /fetching from remote/){|e|
        expect(e.data).to include(
          url: source,
          rev: "missing"
        )
      }
    end

  end

  context '#copy_to' do

    let(:target){
      Dir.mktmpdir("fpm-fry")
    }

    after do
      FileUtils.rm_rf(target)
    end

    it 'copies all contents to the given destination' do
      src = FPM::Fry::Source::Git.new(source)
      cache = src.build_cache(tmpdir)
      cache.copy_to(target)
      expect(Dir.new(target).entries.sort).to eq [".","..","World"]
      expect(IO.read(File.join(target,"World"))).to eq "Hello\n"
    end

  end

  context '#cachekey' do
    it "works" do
      src = FPM::Fry::Source::Git.new(source)
      cache = src.build_cache(tmpdir)
      expect(cache.cachekey).to eq("21f88b4ce08684ba5f9d58eb48b8bad1dfda8f9c")
    end
  end

  context 'url' do

    it 'accepts git@... urls' do
      src = FPM::Fry::Source::Git.new('git@github.com:foo/bar.git')
      expect(src.url.path).to eq '/foo/bar.git'
    end

  end

end
