require 'cabin/nice_output'
require 'fpm/fry/channel'
module FPM; module Fry
  class UI < Struct.new(:out, :err, :logger, :tmpdir)

    def initialize( out: STDOUT, err: STDERR, logger: nil , tmpdir: '/tmp/fpm-fry' )
      logger ||= Channel.new.tap{|chan| chan.subscribe(Cabin::NiceOutput.new(out)) }
      FileUtils.mkdir_p( tmpdir )
      super( out, err, logger, tmpdir )
    end

  end
end ; end
