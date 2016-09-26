require 'fpm/fry/with_data'
describe FPM::Fry::WithData do

  context 'with an exception' do

    let(:exception){ Exception.new }

    it 'keeps exception the same' do
      expect(FPM::Fry::WithData(exception, key: 'value')).to be exception
    end

    it 'adds a data method' do
      expect(FPM::Fry::WithData(exception, key: 'value').data).to eq(key: 'value')
    end

  end

  context 'with a string' do

    it 'returns a StandardError' do
      expect(FPM::Fry::WithData("message", key: 'value')).to be_a StandardError
    end

    it 'keeps the message' do
      expect(FPM::Fry::WithData("message", key: 'value').message).to eq "message"
    end

    it 'adds a data method' do
      expect(FPM::Fry::WithData("message", key: 'value').data).to eq(key: 'value')
    end

  end

  context 'included' do

    let(:klass) do
      Class.new(Exception) do
        include FPM::Fry::WithData
      end
    end

    let(:another_exception) do
      Exception.new('another exception')
    end

    let(:another_exception_with_data) do
      ex = Exception.new('another exception')
      def ex.data
        {another_key: "another_value", key: "another_value"}
      end
      ex
    end

    it 'supports initialization with a message and data' do
      ex = klass.new('message', key: 'value')
      expect(ex.message).to eq 'message'
      expect(ex.data).to eq(key: 'value')
    end

    it 'supports initialization with another exception and data' do
      ex = klass.new(another_exception, key: 'value')
      expect(ex.message).to eq another_exception.message
      expect(ex.data).to eq(key: 'value')
    end

    it 'merges data from exception passed to initialize' do
      ex = klass.new(another_exception_with_data, key: 'value')
      expect(ex.message).to eq another_exception_with_data.message
      expect(ex.data).to eq(another_key: 'another_value', key: 'value')
    end



  end

end
