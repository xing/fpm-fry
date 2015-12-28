require 'fpm/package/docker'
describe FPM::Package::Docker do

  describe '#input' do

    subject{
      described_class.new(client: client)
    }

    after(:each) do
      subject.cleanup_staging
      subject.cleanup_build
    end

    let(:client){
      client = double('client')
      allow(client).to receive(:changes).with('foo').and_return(changes)
      client
    }

    context 'trivial case' do
      let(:changes){
        [
          { "Path"=> "/dev", 'Kind' => 0 },
          { "Path"=> "/dev/sda", 'Kind' => 1 },
          { "Path"=> "/tmp", 'Kind' => 0 },
          { "Path"=> "/tmp/foo", 'Kind' => 1 },
          { "Path"=> "/usr/bin/foo", 'Kind' => 1 }
        ]
      }

      it 'ignores changes in /dev and /tmp' do
        expect(client).to receive(:copy).with('foo','/usr/bin', {'/usr/bin/foo' => a_string_matching(%r!/usr/bin/foo\z!) }, Hash)
        subject.input('foo')
      end
    end

    context 'with excludes set' do
      let(:changes){
        [
          { "Path"=> "/a",'Kind' => 0 },
          { "Path"=> "/a/bar",'Kind' => 1 },
          { "Path"=> "/b",'Kind'=> 0 },
          { "Path"=> "/b/bar",'Kind' => 1 }
        ]
      }

      it 'drops whole directories if requested' do
        expect(client).to receive(:copy).with('foo','/b', {'/b/bar'=> a_string_matching(%r!/b/bar\z!) }, Hash)
        subject.attributes[:excludes] = [
          'a'
        ]
        subject.input('foo')
      end
    end

    context 'broken docker symlink behavior' do
      let(:changes){
        [
          { "Path"=> "/a",'Kind' => 0 },
          { "Path"=> "/a/bar",'Kind' => 1 },
          { "Path"=> "/b",'Kind'=> 0 },
          { "Path"=> "/b/bar",'Kind' => 1 }
        ]
      }

      it 'is fixed by downloading enclosing directories' do
        options = {chown: false}
        map = {
          '/a/bar' => a_string_matching(%r!/a/bar\z!),
          '/b/bar' => a_string_matching(%r!/b/bar\z!)
        }
        expect(client).to receive(:copy).with('foo','/a', map, options)
        expect(client).to receive(:copy).with('foo','/b', map, options)
        subject.input('foo')
      end
    end

    context 'with changed files' do
      let(:changes){
        [
          { "Path"=> "/a", 'Kind' => 0 },
          { "Path"=> "/a/bar", 'Kind' => 0 },
          { "Path"=> "/b", 'Kind' => 0 },
          { "Path"=> "/b/bar", 'Kind' => 1 },
          { "Path"=> "/a", 'Kind' => 0 },
          { "Path"=> "/a/bar", 'Kind' => 2 }
        ]
      }

      it 'drops whole directories if requested' do
        options = {chown: false}
        map = {
          '/b/bar' => a_string_matching(%r!/b/bar\z!)
        }
        expect(client).to receive(:copy).with('foo','/b', map, options)
        subject.input('foo')
      end
    end
  end

  describe '#split', focus: true do

    let(:logger){
      l = double(:logger)
      allow(l).to receive(:debug)
      l
    }

    subject{
      described_class.new(client: client, logger: logger)
    }

    after(:each) do
      subject.cleanup_staging
      subject.cleanup_build
    end

    let(:client){
      client = double('client')
      allow(client).to receive(:changes).with('foo').and_return(changes)
      client
    }

    context 'trivial case' do

      let(:changes){
        [
          { "Path"=> "/a/foo", 'Kind' => 1 },
          { "Path"=> "/b/bar", 'Kind' => 1 }
        ]
      }

      it 'copies files to correct directory' do
        map = {
          "/a/foo"=>"/a/a/foo",
          "/b/bar"=>"/b/b/bar"
        }
        expect(client).to receive(:copy).with('foo','/a', map, Hash)
        expect(client).to receive(:copy).with('foo','/b', map, Hash)
        subject.split('foo', '/a/**' => '/a', '/b/**' => '/b' )
      end
    end

    context 'with modified files' do

      let(:changes){
        [
          { "Path"=> "/a/foo", 'Kind' => 2 },
        ]
      }

      it 'logs a warning' do
        expect(logger).to receive(:warn).with(/modified file/, name: '/a/foo')
        subject.split('foo', '/a/**' => '/a')
      end
    end

  end

end
