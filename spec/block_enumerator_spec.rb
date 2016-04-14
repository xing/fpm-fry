require 'fpm/fry/block_enumerator'
describe FPM::Fry::BlockEnumerator do

  let(:io){
    StringIO.new("abcdefghijk")
  }

  subject{ described_class.new(io,3) }

  context '#each' do

    it "returns an enumerator when called without a block" do
      enum = subject.each
      expect(enum).to be_a Enumerable
      expect{|blk|
        enum.each(&blk)
      }.to yield_successive_args("abc","def","ghi","jk")
    end

    it "yields chunks" do
      expect{|blk|
        subject.each(&blk)
      }.to yield_successive_args("abc","def","ghi","jk")
    end

    it "returns nil with a block" do
      expect(subject.each{}).to be nil
    end

  end

  context '#call' do

    it "reads the io chunkwise" do
      expect(subject.call).to eq "abc"
      expect(subject.call).to eq "def"
      expect(subject.call).to eq "ghi"
      expect(subject.call).to eq "jk"
      expect(subject.call).to eq ""
      expect(subject.call).to eq ""
    end

  end
end
