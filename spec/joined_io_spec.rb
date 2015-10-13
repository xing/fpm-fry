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
end
