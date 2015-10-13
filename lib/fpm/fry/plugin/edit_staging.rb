require 'fpm/fry/plugin'
require 'fileutils'
module FPM::Fry::Plugin::EditStaging

  class AddFile < Struct.new(:path, :io, :options)
    def call(_ , package)
      file = package.staging_path(path)
      FileUtils.mkdir_p(File.dirname(file))
      File.open(file,'w') do | f |
        IO.copy_stream(io, f)
        if options[:chmod]
          f.chmod(options[:chmod])
        end
      end
      io.close if io.respond_to? :close
    end
  end

  class LnS < Struct.new(:src, :dest)
    def call(_ , package)
      file = package.staging_path(dest)
      FileUtils.mkdir_p(File.dirname(file))
      File.symlink(src, file)
    end
  end

  class DSL < Struct.new(:builder)
    def add_file(path, io, options = {})
      options = options.dup
      options[:chmod] = convert_chmod(options[:chmod]) if options[:chmod]
      options.freeze
      io.rewind if io.respond_to? :rewind
      builder.output_hooks << AddFile.new(path, io, options)
    end

    def ln_s(src, dest)
      builder.output_hooks << LnS.new(src,dest)
    end
  private

    def convert_chmod(chmod)
      if chmod.kind_of? Numeric
        num = chmod
      elsif chmod.kind_of? String
        num = chmod.to_i(8)
      else
        raise ArgumentError, "Invalid chmod format: #{chmod}"
      end
      return num
    end

  end

  def self.apply(builder, &block)
    d = DSL.new(builder)
    if !block
      return d
    elsif block.arity == 1
      block.call(d)
    else
      d.instance_eval(&block)
    end
    return d
  end

end
