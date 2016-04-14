require 'fpm/fry/joined_io'
require 'stringio'
describe FPM::Fry::JoinedIO do

  JoinedIO = FPM::Fry::JoinedIO

  describe "#read without length" do
    context 'simple case' do
      subject{ JoinedIO.new(StringIO.new("foo"),StringIO.new("bar")) }

      it "reads everything" do
        expect(subject.read).to eq("foobar")
      end
    end

    context 'empty case' do
      subject{ JoinedIO.new() }

      it "responds with an empty string" do
        expect(subject.read).to eq("")
      end
    end
  end

  describe "#read with length" do
    context 'simple case' do
      subject{ JoinedIO.new(StringIO.new("foo"),StringIO.new("bar")) }

      it "reads everything" do
        expect(4.times.map{ subject.read(2) }).to eq(["fo","ob","ar",nil])
      end
    end

    context 'short read at end' do
      subject{ JoinedIO.new(StringIO.new("foo"),StringIO.new("bar")) }

      it "reads everything" do
        expect(3.times.map{subject.read(4)}).to eq(["foob","ar",nil])
      end
    end

    context 'empty case' do
      subject{ JoinedIO.new() }

      it "responds with nil" do
        expect(subject.read(1)).to eq(nil)
      end
    end
  end

  context "with empty IOs" do
    subject{
      strange_io = double('strangeIO')
      allow(strange_io).to receive(:eof?).and_return(false)
      allow(strange_io).to receive(:read).and_return(nil)
      JoinedIO.new(StringIO.new("foo"), strange_io, StringIO.new("bar"))
    }

    it "reads everything" do
      expect(3.times.map{subject.read(4)}).to eq(["foob","ar",nil])
    end
  end

  context '#close' do
    let(:io1){ double('io1') }
    let(:io2){ double('io2') }
    let(:io3){ double('io3') }

    subject{ JoinedIO.new(io1,io2,io3) }

    it 'closes each IO' do
      expect(io1).to receive(:close)
      expect(io2).to receive(:close)
      expect(io3).to receive(:close)
      subject.close
    end
  end

  context '#eof?' do
    subject{ JoinedIO.new(StringIO.new("foo"),StringIO.new("bar")) }

    it "is false before reading" do
      expect(subject.eof?).to be false
    end

    it "is false after reading some chars" do
      subject.read 5
      expect(subject.eof?).to be false
    end

    it "is false after reading all chars" do
      subject.read 6
      expect(subject.eof?).to be true
    end

    it "is true after reading everything" do
      subject.read
      expect(subject.eof?).to be true
    end
  end

  context '#pos' do

    subject{ JoinedIO.new(StringIO.new("foo"),StringIO.new("bar")) }

    it 'is zero before first read' do
      expect(subject.pos).to eq 0
    end

    it "returns the number of bytes read" do
      subject.read(4)
      expect(subject.pos).to eq 4
    end

  end

end
