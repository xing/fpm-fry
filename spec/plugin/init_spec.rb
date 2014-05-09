require 'fpm/dockery/plugin/init'
describe FPM::Dockery::Plugin::Init do

  subject{
    o = double('foo')
    allow(o).to receive(:variables){ {distribution: distribution, distribution_version: version} }
    o.extend(FPM::Dockery::Plugin::Init)
    o
  }

  describe '#detect_init' do

TESTS = [
%w{ubuntu 12.04 upstart},
%w{ubuntu 14.04 upstart},
%w{ubuntu 14.10 systemd},
%w{debian 5.0.10 sysv},
%w{debian 6.0.1 sysv},
%w{debian 7.0.1 sysv},
%w{debian 8.0.0 systemd},
%w{centos 5.5 sysv},
%w{centos 6.0 upstart},
%w{centos 7.0 systemd}
].each do |d,v, expected|
    context "#{d}-#{v}" do
      let(:distribution){d}
      let(:version){v}

      it "reports #{expected}" do
        expect(subject.init).to eq expected
      end
    end
end

  end
end
