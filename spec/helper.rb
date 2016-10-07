require 'simplecov'
require 'coveralls'
require 'excon'

SimpleCov.start do
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
  ])
  add_filter "/spec"
  maximum_coverage_drop 5
end

module LoggerDouble
  def logger
    @logger ||= begin
      l = double(:logger)
      allow(l).to receive(:debug)
      l
    end
  end
end

module RealDocker

  def self.check!
    return @available if defined? @available
    if ENV['FPM_FRY_DOCKER'] != 'yes'
      puts "Docker test support not explicitly enabled by FPM_FRY_DOCKER=yes. Skipping all real docker tests."
      @available = false
      return @available
    end
    begin
      sv = client.server_version
      puts "Docker #{sv['Version']} ( api #{sv['ApiVersion']} ) available. Enabling real docker tests."
      @available = true
    rescue Excon::Error
      puts "Docker is not available at #{client.docker_url}. Skipping all real docker tests."
      @available = false
    end
    return @available
  end

  def self.available?
    @available
  end

  def self.client
    @client ||= begin
                  require 'fpm/fry/client'
                  FPM::Fry::Client.new
                end
  end

  def self.url
    uri = client.docker_url
    proto, address = uri.split('://',2)
    case(proto)
    when 'unix'
      return 'unix'
    else
      return address
    end
  end

  def requires_docker
    skip "This test requires docker" unless RealDocker.available?
  end

  def real_docker
    requires_docker
    RealDocker.client
  end

  def with_container(image)
    docker = real_docker
    begin
      container = docker.create(image)
    rescue Excon::Error::NotFound
      docker.pull(image)
      container = docker.create(image)
    end
    begin
      yield container
    ensure
      docker.destroy(container)
    end
  end

  def with_inspector(image)
    with_container(image){|cont|
      yield FPM::Fry::Inspector.new(real_docker, cont)
    }
  end

end

RealDocker.check!

require 'webmock/rspec'
WebMock.disable_net_connect!( allow: RealDocker.url )

RSpec.configure do |config|
  config.include LoggerDouble
  config.include RealDocker
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

class IOFilter < Struct.new(:io)
  def pos
    0
  end

  def read(*args)
    return io.read(*args)
  end

  def eof?
    io.eof?
  end
end

