require 'fpm/fry/channel'
describe FPM::Fry::Channel do

  subject{
    chan = FPM::Fry::Channel.new
    chan.subscribe subscriber
    chan
  }

  let(:subscriber){
    double(:subscriber)
  }

  context 'with exceptions' do
    it 'allows logging exceptions' do
      ex = Exception.new("foo")
      expect(subscriber).to receive(:<<).with({level: :error, message: "foo", exception: ex, backtrace: nil})
      subject.error(ex)
    end

    it "merges #data" do
      ex = Exception.new("foo")
      def ex.data
        {blub: "bla"}
      end
      expect(subscriber).to receive(:<<).with({level: :error, message: "foo", exception: ex, backtrace: nil, blub: "bla"})
      subject.error(ex)
    end

    it "doesn't allow overwriting" do
      ex = Exception.new("foo")
      def ex.data
        {blub: "bla", message: "bar", level: :warning}
      end
      expect(subscriber).to receive(:<<).with({level: :error, message: "foo", exception: ex, backtrace: nil, blub: "bla"})
      subject.error(ex)
    end
  end

  context 'with a Hash' do
    it 'dups the hash' do
      expect(subscriber).to receive(:<<).with({level: :info, blub: "blub"}){|data|
        data[:foo] = 'bar'
      }
      hsh = {blub: 'blub'}
      subject.info(hsh)
      expect(hsh).not_to include(:foo)
    end
  end

  context '#hint' do
    it 'uses the hint level' do
      expect(subscriber).to receive(:<<).with({level: :hint, message: "bar"})
      subject.hint("bar")
    end

    it 'can be disabled with #hint=' do
      subject.hint = false
      subject.hint("bar")
    end
  end

end
