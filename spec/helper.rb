require 'simplecov'
require 'coveralls'
SimpleCov.start do
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
  ])
  add_filter "/spec"
  add_filter "lib/fpm/fry/os_db.rb"
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

RSpec.configure do |config|
  config.include LoggerDouble
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

