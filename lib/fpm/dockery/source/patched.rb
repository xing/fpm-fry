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
          if !File.directory?(unpacked_tmpdir)
            workdir = unpacked_tmpdir + '.tmp'
            begin
              FileUtils.mkdir(workdir)
            rescue Errno::EEXIST
              FileUtils.rm_rf(workdir)
              FileUtils.mkdir(workdir)
            end
            if inner.respond_to? :copy_to
              inner.copy_to(workdir)
            else
              ex = Tar::Extractor.new(logger: logger)
              tio = inner.tar_io
              begin
                ex.extract(workdir, ::Gem::Package::TarReader.new(tio), chown: false)
              ensure
                tio.close
              end
            end
            package.patches.each do |patch|
              cmd = ['patch','-p1','-i',patch[:file]]
              chdir = File.expand_path(patch.fetch(:chdir,'.'),workdir)
              logger.debug("Running patch",cmd: cmd, dir: chdir )
              system(*cmd, chdir: chdir, out: :close)
            end
            File.rename(workdir, unpacked_tmpdir)
          end
          true
        end
      end
      private :update!

      def tar_io
        update!
        cmd = ['tar','-c','.']
        logger.debug("Running tar",cmd: cmd, dir: unpacked_tmpdir)
        # IO.popen( ..., chdir: ... ) doesn't work on older ruby
        ::Dir.chdir(unpacked_tmpdir) do
          return IO.popen(cmd)
        end
      end

      def cachekey
        dig = Digest::SHA2.new
        dig << inner.cachekey << "\x00"
        package.patches.each do |patch|
          dig.file(patch[:file])
          dig << "\x00"
        end
        return dig.hexdigest
      end

      def unpacked_tmpdir
        File.join(tmpdir, cachekey)
      end

    end

    attr :inner, :patches

    extend Forwardable

    def_delegators :inner, :logger, :file_map

    def initialize( inner , options = {})
      @inner = inner
      @patches = Array(options[:patches]).map do |file|
        if file.kind_of? String
          options = {file: file}
        elsif file.kind_of? Hash
          options = file.dup
        else
          raise ArgumentError, "Expected a Hash or a String, got #{file.inspect}"
        end
        options[:file] = File.expand_path(options[:file])
        if !File.exists?(options[:file])
          raise ArgumentError, "File doesn't exist: #{options[:file]}"
        end
        options
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

