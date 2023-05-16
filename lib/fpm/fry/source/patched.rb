require 'fpm/fry/tar'
require 'fpm/fry/exec'
require 'digest'
module FPM; module Fry ; module Source
  class Patched

    class Cache < Struct.new(:package, :tmpdir)
      extend Forwardable

      def_delegators :package, :logger, :file_map
      def_delegators :inner, :prefix, :to

      attr :inner

      def initialize(*_)
        @updated = false
        super
        @inner = package.inner.build_cache(tmpdir)
      end

      def update!
        return if @updated
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
              ex.extract(workdir, FPM::Fry::Tar::Reader.new(tio), chown: false)
            ensure
              tio.close
            end
          end
          base = workdir
          if inner.respond_to? :prefix
            base = File.expand_path(inner.prefix, base)
          end
          package.patches.each do |patch|
            cmd = ['patch','-t','-p1','-i',patch[:file]]
            chdir = base
            if patch.key? :chdir
              given_chdir = File.expand_path(patch[:chdir],workdir)
              if given_chdir != chdir
                chdir = given_chdir
              else
                logger.hint("You can remove the chdir: #{patch[:chdir].inspect} option for #{patch[:file]}. The given value is the default.", documentation: 'https://github.com/xing/fpm-fry/wiki/Source-patching#chdir' )
              end
            end
            begin
              Fry::Exec[*cmd, chdir: chdir, logger: logger]
            rescue Exec::Failed => e
              raise CacheFailed.new(e, patch: patch[:file])
            end
          end
          File.rename(workdir, unpacked_tmpdir)
        else
          #
          base = unpacked_tmpdir
          if inner.respond_to? :prefix
            base = File.expand_path(inner.prefix, base)
          end
          package.patches.each do |patch|
            if patch.key? :chdir
              given_chdir = File.expand_path(patch[:chdir],unpacked_tmpdir)
              if given_chdir == base
                logger.hint("You can remove the chdir: #{patch[:chdir].inspect} option for #{patch[:file]}. The given value is the default.", documentation: 'https://github.com/xing/fpm-fry/wiki/Source-patching#chdir' )
              end
            end
          end
        end
        @updated = true
      end
      private :update!

      def tar_io
        update!
        return Exec::popen('tar','-c','.',chdir: unpacked_tmpdir, logger: logger)
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

    attr :inner, :logger, :patches

    extend Forwardable

    def_delegators :inner, :file_map

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
        if !File.exist?(options[:file])
          raise ArgumentError, "File doesn't exist: #{options[:file]}"
        end
        options
      end
      if @inner.respond_to? :logger
        @logger = @inner.logger
      else
        @logger = Cabin::Channel.get
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
