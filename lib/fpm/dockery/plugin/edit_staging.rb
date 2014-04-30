require 'fpm/dockery/plugin'
require 'fileutils'
module FPM::Dockery::Plugin::EditStaging

  class AddFile < Struct.new(:path, :io)
    def call(_ , package)
      file = package.staging_path(path)
      FileUtils.mkdir_p(File.dirname(file))
      File.open(file,'w') do | f |
        IO.copy_stream(io, f)
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

  class DSL < Struct.new(:recipe)
    def add_file(path, io)
      io.rewind if io.respond_to? :rewind
      recipe.hooks << AddFile.new(path, io)
    end

    def ln_s(src, dest)
      recipe.hooks << LnS.new(src,dest)
    end
  end

  def self.apply(builder, &block)
    d = DSL.new(builder.recipe)
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
