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
        expect(client).to receive(:copy).with('foo','/usr/bin', a_string_matching(%r!usr/bin!), Hash)
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
        expect(client).to receive(:copy).with('foo','/b', a_string_matching(%r!b\z!), Hash)
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
        options = {chown: false, only: {'/a/bar'=> true, '/b/bar' => true }}
        expect(client).to receive(:copy).with('foo','/a', a_string_matching(%r!a!), options)
        expect(client).to receive(:copy).with('foo','/b', a_string_matching(%r!b!), options)
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
        options = {chown: false, only: {'/b/bar' => true }}
        expect(client).to receive(:copy).with('foo','/b', a_string_matching(%r!b!), options)
        subject.input('foo')
      end
    end
  end
end
