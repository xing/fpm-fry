require 'fpm/dockery/tar'
require 'digest'
module FPM; module Dockery ; module Source
  class Patched

    class Cache < Struct.new(:package, :tmpdir)
      extend Forwardable

      def_delegators :package, :logger, :file_map

      attr :inner

      def initialize(*_)
        @updated = false
        super
        @inner = package.inner.build_cache(tmpdir)
      end

      def update!
        @updated ||= begin
          if inner.respond_to? :copy_to
            inner.copy_to(tmpdir)
          else
            ex = Tar::Extractor.new(logger: logger)
            tio = inner.tar_io
            begin
              ex.extract(tmpdir, ::Gem::Package::TarReader.new(tio), chown: false)
            ensure
              tio.close
            end
          end
          package.patches.each do |patch|
            cmd = ['patch','-p1','-i',patch]
            logger.debug("Running patch",cmd: cmd, dir: tmpdir)
            system(*cmd, chdir: tmpdir, out: :close)
          end
          true
        end
      end
      private :update!

      def tar_io
        update!
        cmd = ['tar','-c','.']
        logger.debug("Running tar",cmd: cmd, dir: tmpdir)
        IO.popen(cmd, chdir: tmpdir)
      end

      def cachekey
        dig = Digest::SHA2.new
        dig << inner.cachekey << "\x00"
        package.patches.each do |patch|
          dig.file(patch)
          dig << "\x00"
        end
        return dig.hexdigest
      end

    end

    attr :inner, :patches

    extend Forwardable

    def_delegators :inner, :logger, :file_map

    def initialize( inner , options = {})
      @inner = inner
      @patches = Array(options[:patches]).map do |file|
        file = File.expand_path(file)
        if !File.exists?(file)
          raise ArgumentError, "File doesn't exist: #{file}"
        end
        file
      end
    end

    def build_cache(tmpdir)
      Cache.new(self,tmpdir)
    end

    def self.decorate(options)
      if options.key?(:patches) && Array(options[:patches]).size > 0
        p = options.delete(:patches)
        return new( yield(options), patches: p )
      else
        return yield options
      end
    end
  end

end ; end ; end

