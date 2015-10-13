require 'stringio'
require 'fpm/fry/stream_parser'
describe FPM::Fry::StreamParser do

  let(:err){ double("err") }
  let(:out){ double("out") }
  subject{ described_class.new( out, err ) }

  context 'trivial case' do

    let(:input){
      StringIO.new([2,6,"stderr",1,6,"stdout"].pack("I<I>Z6I<I>Z6"))
    }

    it "seperates stderr and stdout correctly" do
      expect(err).to receive(:write).with("stderr")
      expect(out).to receive(:write).with("stdout")
      subject.parse(input)
    end

  end

  context 'invalid stream type' do

    let(:input){
      StringIO.new([3,7,"invalid"].pack("I<I>Z7"))
    }

    it "barfs" do
      expect{
        subject.parse(input)
      }.to raise_error(ArgumentError,/Wrong stream type: 3/)
    end

  end

  context 'unknown bytes after type' do

    let(:input){
      StringIO.new([1,3,3,3,7,"unknown"].pack("ccccI>Z7"))
    }

    it "ignores them" do
      expect(out).to receive(:write).with("unknown")
      subject.parse(input)
    end

  end

  context 'short read in content' do

    let(:input){
      StringIO.new([1,7,"short"].pack("I<I>Z5"))
    }

    it "raises an error" do
      expect(out).to receive(:write).with("short")
      expect{ subject.parse(input) }.to raise_error(FPM::Fry::StreamParser::ShortRead)
    end

  end

  context 'short read in length' do

    let(:input){
      StringIO.new([1,1].pack("I<c"))
    }

    it "raises an error" do
      expect{ subject.parse(input) }.to raise_error(FPM::Fry::StreamParser::ShortRead)
    end

  end

  context 'short read in type' do

    let(:input){
      StringIO.new([1].pack("c"))
    }

    it "raises an error" do
      expect{ subject.parse(input) }.to raise_error(FPM::Fry::StreamParser::ShortRead)
    end

  end

  describe 'Instance' do

    let(:stack){
      s = double(:stack)
      allow(s).to receive(:response_call){|arg| arg }
      s
    }
    let(:socket){
      double(:socket)
    }
    let(:connection){
      con = double(:connetion)
      allow(con).to receive(:socket){ socket }
      con
    }
    let(:datum){
      { connection: connection }
    }

    subject{ described_class.new( out, err ).new(stack) }

    context 'empty response' do
      let(:socket){
        StringIO.new(<<IO)
HTTP/1.1 200 Success

IO
      }
      it "works" do
        # no assertions here because the output stream have implict assertions
        subject.response_call(datum)
      end
    end

    context 'simple response' do
      let(:socket){
        StringIO.new(<<IO.chomp)
HTTP/1.1 200 Success
Foo: Bar

#{[2,6,"stderr",1,6,"stdout"].pack("I<I>Z6I<I>Z6")}
IO
      }
      it "works" do
        expect(err).to receive(:write).with("stderr")
        expect(out).to receive(:write).with("stdout")
        res = subject.response_call(datum)
        expect( res[:response][:headers] ).to eq('Foo' => 'Bar')
      end
    end


  end

end
