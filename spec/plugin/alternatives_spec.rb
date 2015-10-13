require 'fpm/fry/plugin/alternatives'

describe FPM::Fry::Plugin::Alternatives do

  let(:recipe){ FPM::Fry::Recipe.new }

  let(:package){ recipe.packages[0] }

  let(:builder){
    FPM::Fry::Recipe::Builder.new({flavour: "debian"},recipe)
  }

  context 'alternatives as string' do

    before(:each) do
      builder.plugin('alternatives',
                      'java' => '/opt/java/bin/java'
                    )
    end

    it 'adds an after_install' do
      expect(package.scripts[:after_install].first.configure).to eq ["update-alternatives --install /usr/bin/java java /opt/java/bin/java 10000"]
    end

    it 'adds an before_remove' do
      expect(package.scripts[:before_remove].first.remove).to eq ["update-alternatives --remove java /opt/java/bin/java"]
    end

  end

  context 'alternatives as options' do

    before(:each) do
      builder.plugin('alternatives',
                      'java' => { path: '/opt/java/bin/java', priority: 123, link: '/usr/local/bin/java'}
                    )
    end

    it 'adds an after_install' do
      expect(package.scripts[:after_install].first.configure).to eq ["update-alternatives --install /usr/local/bin/java java /opt/java/bin/java 123"]
    end

    it 'adds an before_remove' do
      expect(package.scripts[:before_remove].first.remove).to eq ["update-alternatives --remove java /opt/java/bin/java"]
    end

  end

  context 'alternatives with slaves' do

    before(:each) do
      builder.plugin('alternatives',
                      'java' => {
                        path: '/opt/java/bin/java',
                        priority: 123,
                        link: '/usr/local/bin/java',
                        slaves: {
                          'jar' => '/opt/java/bin/jar'
                        }
                      }
                    )
    end

    it 'adds an after_install' do
      expect(package.scripts[:after_install].first.configure).to eq ["update-alternatives --install /usr/local/bin/java java /opt/java/bin/java 123 --slave /usr/bin/jar jar /opt/java/bin/jar"]
    end

    it 'adds an before_remove' do
      expect(package.scripts[:before_remove].first.remove).to eq ["update-alternatives --remove java /opt/java/bin/java"]
    end

  end

end
