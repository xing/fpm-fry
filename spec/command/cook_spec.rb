require 'tmpdir'
require 'fileutils'
require 'fpm/dockery/command/cook'
describe FPM::Dockery::Command::Cook do

  let(:tmpdir) do
    Dir.mktmpdir('fpm-dockery')
  end

  let(:ui) do
    FPM::Dockery::UI.new(StringIO.new,StringIO.new,nil,tmpdir)
  end

  after(:each) do
    FileUtils.rm_rf(tmpdir)
  end


  context 'without recipe' do
    subject do
      s = FPM::Dockery::Command::Cook.new('fpm-dockery', ui: ui)
    end

    it 'returns an error' do
      expect(subject.logger).to receive(:error).with("Recipe not found", a_hash_including(recipe: "recipe.rb"))
      expect(subject.execute).to eq 1
    end
  end

  describe '#output_class' do

    subject do
      FPM::Dockery::Command::Cook.new('fpm-dockery', ui: ui)
    end

    context 'debian-automatic' do
      before(:each) do
        subject.flavour = 'debian'
      end
      it 'returns Deb' do
        expect(subject.output_class).to eq FPM::Package::Deb
      end
    end

    context 'redhat-automatic' do
      before(:each) do
        subject.flavour = 'redhat'
      end
      it 'returns Deb' do
        expect(subject.output_class).to eq FPM::Package::RPM
      end
    end

  end

  describe '#builder' do

    subject do
      FPM::Dockery::Command::Cook.new('fpm-dockery', ui: ui)
    end

    context 'trivial case' do
      before(:each) do
        subject.detector = FPM::Dockery::Detector::String.new('ubuntu-12.04')
        subject.flavour = 'debian'
        subject.recipe = File.expand_path('../data/recipe.rb',File.dirname(__FILE__))
      end
      it 'works' do
        expect(subject.builder).to be_a FPM::Dockery::Recipe::Builder
      end
      it 'contains the right variables' do
        expect(subject.builder.variables).to eq(distribution: 'ubuntu', distribution_version: '12.04', flavour: 'debian', codename: 'precise')
      end
      it 'has loaded the right recipe' do
        expect(subject.builder.recipe.name).to eq 'foo'
      end
    end

  end

  describe '#image_id' do
    subject do
      FPM::Dockery::Command::Cook.new('fpm-dockery', ui: ui)
    end

    context 'with an existing image' do
      before(:each) do
        subject.image = 'foo:bar'
        stub_request(:get, "http://unix/version").
          to_return(:status => 200, :body =>'{"ApiVersion":"1.9"}', :headers => {})
        stub_request(:get, "http://unix/v1.9/images/foo:bar/json").
                     to_return(:status => 200, :body => "{\"id\":\"deadbeef\"}")
      end
      it 'returns the id' do
        expect(subject.image_id).to eq 'deadbeef'
      end
    end
  end

  describe '#build_image' do
    subject do
      FPM::Dockery::Command::Cook.new('fpm-dockery', ui: ui)
    end

    context 'with an existing cache image' do
      let(:builder) do
        FPM::Dockery::Recipe::Builder.new({}, FPM::Dockery::Recipe.new, logger: subject.logger)
      end

      before(:each) do
        subject.image_id = 'f'*32
        subject.flavour  = 'unknown'
        subject.cache = FPM::Dockery::Source::Null::Cache
        subject.builder = builder
        stub_request(:get, "http://unix/version").
          to_return(:status => 200, :body =>'{"ApiVersion":"1.9"}', :headers => {})
        stub_request(:get, "http://unix/v1.9/images/fpm-dockery:5cb0db32efafac12020670506c62c39/json").
                    to_return(:status => 200, :body => "")
        stub_request(:post, "http://unix/v1.9/build?rm=1").
                    with(:headers => {'Content-Type'=>'application/tar'}).
                    to_return(:status => 200, :body => '{"stream":"Successfully built deadbeef"}', :headers => {})
      end
      it 'returns the id' do
        expect(subject.build_image).to eq 'deadbeef'
      end
    end

    context 'without an existing cache image' do
      let(:builder) do
        FPM::Dockery::Recipe::Builder.new({}, FPM::Dockery::Recipe.new, logger: subject.logger)
      end

      before(:each) do
        subject.image_id = 'f'*32
        subject.flavour  = 'unknown'
        subject.cache = FPM::Dockery::Source::Null::Cache
        subject.builder = builder
        stub_request(:get, "http://unix/version").
          to_return(:status => 200, :body =>'{"ApiVersion":"1.9"}', :headers => {})
        stub_request(:get, "http://unix/v1.9/images/fpm-dockery:5cb0db32efafac12020670506c62c39/json").
                    to_return(:status => 404)
        stub_request(:post, "http://unix/v1.9/build?rm=1&t=fpm-dockery:5cb0db32efafac12020670506c62c39").
                    with(:headers => {'Content-Type'=>'application/tar'}).
                    to_return(:status => 200, :body => '{"stream":"Successfully built xxxxxxxx"}', :headers => {})
        stub_request(:post, "http://unix/v1.9/build?rm=1").
                    with(:headers => {'Content-Type'=>'application/tar'}).
                    to_return(:status => 200, :body => '{"stream":"Successfully built deadbeef"}', :headers => {})
      end
      it 'returns the id' do
        expect(subject.build_image).to eq 'deadbeef'
      end
    end

  end

  describe '#build!' do
    subject do
      FPM::Dockery::Command::Cook.new('fpm-dockery', ui: ui)
    end

    context 'trivial case' do

      before(:each) do
        subject.build_image = 'fpm-dockery:x'
        stub_request(:get, "http://unix/version").
          to_return(:status => 200, :body =>'{"ApiVersion":"1.9"}', :headers => {})
        stub_request(:post, "http://unix/v1.9/containers/create").
          with(:body => "{\"Image\":\"fpm-dockery:x\"}",
               :headers => {'Content-Type'=>'application/json'}).
          to_return(:status => 201, :body => '{"Id":"caafffee"}')
        stub_request(:post, "http://unix/v1.9/containers/caafffee/start").
          with(:body => "{}",
               :headers => {'Content-Type'=>'application/json'}).
          to_return(:status => 204)
        stub_request(:post, "http://unix/v1.9/containers/caafffee/attach?stderr=1&stdout=1&stream=1").
          to_return(:status => 200, :body => [2,6,"stderr",1,6,"stdout"].pack("I<I>Z6I<I>Z6"))
        stub_request(:post, "http://unix/v1.9/containers/caafffee/wait").
          to_return(:status => 200, :body => '{"StatusCode":0}')
        stub_request(:delete, "http://unix/v1.9/containers/caafffee").
          to_return(:status => 200)
      end
      it 'yields the id' do
        expect{|yld| subject.build!(&yld) }.to yield_with_args('caafffee')
      end
    end
  end

  describe '#update?' do

    let(:client) do
      c = double('client')
      allow(c).to receive(:url){|*args| args.join('/') }
      c
    end

    subject do
      s = FPM::Dockery::Command::Cook.new('fpm-dockery', ui: ui)
      s.client = client
      s
    end

    context 'debian auto without cache' do

      before(:each) do
        subject.flavour = 'debian'
        subject.image = 'ubuntu:precise'
        allow(subject.client).to receive(:post).
          with(a_hash_including(path: 'containers/create')).
          and_return(double('response', body: '{"Id":"deadbeef"}'))
        allow(subject.client).to receive(:read).
          with('deadbeef','/var/lib/apt/lists').
          and_yield(double('lists', header: double('lists.header', name: 'lists/')))
        allow(subject.client).to receive(:delete).
          with(a_hash_including(path: 'containers/deadbeef'))
      end

      it 'is true' do
        expect(subject.update?).to eq true
      end
    end

    context 'debian auto with cache' do

      before(:each) do
        subject.flavour = 'debian'
        subject.image = 'ubuntu:precise'
        allow(subject.client).to receive(:post).
          with(a_hash_including(path: 'containers/create')).
          and_return(double('response', body: '{"Id":"deadbeef"}'))
        allow(subject.client).to receive(:read).
          with('deadbeef','/var/lib/apt/lists').
          and_yield(double('lists', header: double('lists.header', name: 'lists/'))).
          and_yield(double('cache', header: double('cache.header', name: 'lists/doenst_matter')))
        allow(subject.client).to receive(:delete).
          with(a_hash_including(path: 'containers/deadbeef'))
      end

      it 'is true' do
        expect(subject.update?).to eq false
      end
    end



  end

end
