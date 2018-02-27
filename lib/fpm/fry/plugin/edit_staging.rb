require 'stringio'
require 'fpm/fry/plugin'
require 'fileutils'
# A plugin to edit the final build results.
# @example Add a file
#   plugin 'edit_staging' do
#     add_file '/a_file', 'some content'
#   end
module FPM::Fry::Plugin::EditStaging

  # @api private
  class AddFile < Struct.new(:path, :io, :options)
    def call(_ , package)
      file = package.staging_path(path)
      package.logger.debug("Writing file directly to staging", target: file, content: io.inspect)
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

  # @api private
  class LnS < Struct.new(:src, :dest)
    def call(_ , package)
      file = package.staging_path(dest)
      package.logger.debug("Linking file directly in staging", target: file, to: src)
      FileUtils.mkdir_p(File.dirname(file))
      File.symlink(src, file)
    end
  end

  class DSL < Struct.new(:builder)

    # @param [String] path
    # @param [IO, String] content
    def add_file(path, content, options = {})
      if content.kind_of?(IO) || content.kind_of?(StringIO)
        io = content
      elsif content.kind_of? String
        io = StringIO.new(content)
      else
        raise ArgumentError.new("File content must be a String or IO, got #{content.inspect}")
      end
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

  # @yield [dsl]
  # @yieldparam [DSL] dsl
  # @return [DSL]
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
