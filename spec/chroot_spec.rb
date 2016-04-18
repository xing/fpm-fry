require 'fpm/fry/chroot'
require 'tmpdir'
require 'fileutils'
describe FPM::Fry::Chroot do

  Chroot = FPM::Fry::Chroot

  let(:tmpdir) do
    Dir.mktmpdir('fpm-fry')
  end

  after(:each) do
    FileUtils.rm_rf(tmpdir)
  end

  subject{
    Chroot.new(tmpdir)
  }

  describe '.new' do
    context 'with a directory' do
      it 'works' do
        ch = Chroot.new(tmpdir)
        expect(ch.base).to eq tmpdir
      end
    end

    context 'with a non-directory' do
      it 'raises an error' do
        expect{
          Chroot.new("something else")
        }.to raise_error(ArgumentError, /Base .* is not a directory/)
      end
    end
  end

  describe '#entries' do
    context 'with a directory' do
      before(:each) do
        FileUtils.mkdir File.join(tmpdir, "a_dir")
        FileUtils.touch File.join(tmpdir, "a_dir", "x")
        FileUtils.touch File.join(tmpdir, "a_dir", "y")
        FileUtils.touch File.join(tmpdir, "a_dir", "z")
      end

      it 'returns all entries' do
        expect(subject.entries('a_dir')).to contain_exactly ".","..","x","y","z"
      end
    end

    context 'with a non-existing directory' do
      it 'raises an error' do
        expect{subject.entries('nx_dir')}.to raise_error(Errno::ENOENT){|ex| expect(ex.data).to eq(path: 'nx_dir') }
      end
    end

    context 'with a file' do
      before(:each) do
        FileUtils.touch File.join(tmpdir, "a_file")
      end

      it 'returns all entries' do
        expect{subject.entries('a_file')}.to raise_error(Errno::ENOTDIR){|ex| expect(ex.data).to eq(path: 'a_file') }
      end
    end

  end

  describe '#open' do
    context 'with a file' do
      before(:each) do
        IO.write File.join(tmpdir, "a_file"), "some content"
      end

      it 'opens the file' do
        fl = subject.open 'a_file'
        expect(fl).to be_a File
        expect(fl.read).to eq "some content"
      end
    end

    context 'with a non-existing file' do
      it 'raises an error when reading' do
        expect{
          subject.open 'nx_file'
        }.to raise_error(Errno::ENOENT){|ex|
          expect(ex.data).to eq path: 'nx_file'
        }
      end

      it 'creates the file with the right mode' do
        file = subject.open 'nx_file', 'w+'
        file.write 'some content'
        file.close
        expect(IO.read File.join(tmpdir,'nx_file')).to eq 'some content'
      end
    end
  end

  describe '#find' do
    context 'with a directory' do
      before(:each) do
        FileUtils.mkdir File.join(tmpdir, "a_dir")
        FileUtils.touch File.join(tmpdir, "a_dir", "x")
        FileUtils.touch File.join(tmpdir, "a_dir", "y")
        FileUtils.touch File.join(tmpdir, "a_dir", "z")
      end

      it 'yields all entries' do
        result = []
        subject.find('a_dir'){|e| result << e }
        expect(result).to contain_exactly "a_dir","a_dir/x","a_dir/y","a_dir/z"
      end
    end

    context 'with a multi-level directory' do
      before(:each) do
        FileUtils.mkdir File.join(tmpdir, "a_dir")
        FileUtils.mkdir File.join(tmpdir, "a_dir", "a_subdir")
        FileUtils.touch File.join(tmpdir, "a_dir", "a_subdir","x")
        FileUtils.touch File.join(tmpdir, "a_dir", "a_subdir","y")
        FileUtils.touch File.join(tmpdir, "a_dir", "a_subdir","z")
        FileUtils.mkdir File.join(tmpdir, "a_dir", "another_subdir")
        FileUtils.touch File.join(tmpdir, "a_dir", "another_subdir","x")
        FileUtils.touch File.join(tmpdir, "a_dir", "another_subdir","y")
        FileUtils.touch File.join(tmpdir, "a_dir", "another_subdir","z")
      end

      it 'yields all entries' do
        result = []
        subject.find('a_dir'){|e| result << e }
        expect(result).to contain_exactly "a_dir","a_dir/a_subdir","a_dir/a_subdir/x","a_dir/a_subdir/y","a_dir/a_subdir/z",
          "a_dir/another_subdir","a_dir/another_subdir/x","a_dir/another_subdir/y","a_dir/another_subdir/z"
      end
    end

    context 'with a file' do
      before(:each) do
        FileUtils.touch File.join(tmpdir, "a_file")
      end

      it 'yields the file' do
        result = []
        subject.find('a_file'){|e| result << e }
        expect(result).to contain_exactly 'a_file'
      end
    end
  end

  describe '#lstat' do
    context 'with a symlink' do
      before(:each) do
        FileUtils.touch File.join(tmpdir, "y")
        File.symlink "y",File.join(tmpdir, "x")
      end

      it 'doesn\'t follow the last symlink' do
        expect(subject.lstat('x')).to eq File.lstat(File.join(tmpdir,'y'))
      end
    end

    context 'with symlinks in path' do
      before(:each) do
        FileUtils.mkdir File.join(tmpdir, "a_dir")
        FileUtils.mkdir File.join(tmpdir, "another_dir")
        File.symlink "../another_dir", File.join(tmpdir, "a_dir","a_subdir")
        File.symlink "/a_dir", File.join(tmpdir, "another_dir","a_link")
      end

      it 'follows all but the last symlink' do
        expect(subject.lstat('a_dir/a_subdir/a_link')).to eq File.lstat(File.join(tmpdir,'another_dir','a_link'))
      end
    end
  end

  describe 'path normalization' do
    context 'with a simple absolute symlink' do
      before(:each) do
        FileUtils.mkdir File.join(tmpdir, "a_dir")
        FileUtils.touch File.join(tmpdir, "y")
        File.symlink "/y",File.join(tmpdir, "a_dir", "x")
      end

      it 'finds the right target' do
        expect(subject.stat('a_dir/x')).to eq File.stat(File.join(tmpdir,'y'))
      end
    end

    context 'with a simple relative symlink' do
      before(:each) do
        FileUtils.touch File.join(tmpdir, "y")
        File.symlink "y",File.join(tmpdir, "x")
      end

      it 'finds the right target' do
        expect(subject.stat('x')).to eq File.stat(File.join(tmpdir,'y'))
      end
    end

    context 'with a simple dotted relative symlink' do
      before(:each) do
        FileUtils.touch File.join(tmpdir, "y")
        File.symlink "./y",File.join(tmpdir, "x")
      end

      it 'finds the right target' do
        expect(subject.stat('x')).to eq File.stat(File.join(tmpdir,'y'))
      end
    end

    context 'with an escaping relative symlink' do
      before(:each) do
        FileUtils.touch File.join(tmpdir, "y")
        File.symlink "../../../y",File.join(tmpdir, "x")
      end

      it 'finds the right target' do
        expect(subject.stat('x')).to eq File.stat(File.join(tmpdir,'y'))
      end
    end
  end

end
