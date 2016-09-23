require 'fpm/fry/recipe/builder'
require 'fpm/fry/inspector'
require 'fpm/fry/plugin/init'
describe FPM::Fry::Plugin::Init do

  context 'init detection (real)' do

    context 'with ubuntu:16.04' do
      it 'finds systemd' do
        with_inspector('ubuntu:16.04') do |insp|
          builder = FPM::Fry::Recipe::Builder.new({},inspector: insp)
          builder.extend(FPM::Fry::Plugin::Init)
          expect(builder.init).to eq :systemd
        end
      end
    end

    context 'with ubuntu:14.04' do
      it 'finds upstart' do
        with_inspector('ubuntu:14.04') do |insp|
          builder = FPM::Fry::Recipe::Builder.new({},inspector: insp)
          builder.extend(FPM::Fry::Plugin::Init)
          expect(builder.init).to eq :upstart
          expect(builder.init).not_to be_with :chkconfig
          expect(builder.init).to be_with :sysvcompat
        end
      end
    end

    context 'with centos:centos7' do
      it 'finds systemd' do
        with_inspector('centos:centos7') do |insp|
          builder = FPM::Fry::Recipe::Builder.new({},inspector: insp)
          builder.extend(FPM::Fry::Plugin::Init)
          expect(builder.init).to eq :systemd
        end
      end
    end

    context 'with centos:centos6' do
      it 'finds upstart' do
        with_inspector('centos:centos6') do |insp|
          builder = FPM::Fry::Recipe::Builder.new({},inspector: insp)
          builder.extend(FPM::Fry::Plugin::Init)
          expect(builder.init).to eq :upstart
          expect(builder.init).not_to be_with :sysvcompat
        end
      end
    end

    context 'with debian:squeeze' do
      it 'finds sysv' do
        with_inspector('debian:squeeze') do |insp|
          builder = FPM::Fry::Recipe::Builder.new({},inspector: insp)
          builder.extend(FPM::Fry::Plugin::Init)
          expect(builder.init).to eq :sysv
          expect(builder.init).not_to be_with :chkconfig
          expect(builder.init).to be_with :'update-rc.d'
          expect(builder.init).to be_with :'invoke-rc.d'
        end
      end
    end


  end

end
