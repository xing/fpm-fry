require 'fpm/dockery/tar'
module FPM; module Dockery ; module Source
  class Patched

    class Cache < Struct.new(:package, :tmpdir)
      extend Forwardable

      def_delegators :package, :logger, :file_map

      def update
        ex = Tar::Extractor.new(logger: logger)
        inner = package.inner.build_cache(tmpdir)
        tio = inner.tar_io
        begin
          ex.extract(tmpdir, ::Gem::Package::TarReader.new(tio))
        ensure
          tio.close
        end
        package.patches.each do |patch|
          cmd = ['patch','-p1','-i',patch]
          logger.debug("Running patch",cmd: cmd, dir: tmpdir)
          system(*cmd, chdir: tmpdir, out: :close)
        end
        return self
      end

      def tar_io
        cmd = ['tar','-c','.']
        logger.debug("Running tar",cmd: cmd, dir: tmpdir)
        IO.popen(cmd, chdir: tmpdir)
      end
    end

    attr :inner, :logger, :file_map, :patches

    def initialize( inner , options = {})
      @inner = inner
      @logger = options.fetch(:logger){ 
        inner.respond_to?(:logger) ? inner.logger : Cabin::Channel.get
      }
      @patches = Array(options[:patches])
      @file_map = options.fetch(:file_map,{''=>''})
    end

    def build_cache(tmpdir)
      Cache.new(self,tmpdir).update
    end
  end

end ; end ; end

