require 'fpm/fry/plugin'
# The env plugin sets global environment variables.
# 
# @example add something to PATH in a recipe
#   plugin 'env', 'PATH' => '$PATH:/usr/local/go/bin'
# 
module FPM::Fry::Plugin::Env

  # @api private
  class AddEnv < Struct.new(:env)

    def call(_, df)
      df[:source] << format
    end
  private

    def format
      "ENV " + env.map{|k,v| "#{k}=#{escape(v)}" }.join(" ")
    end

    def escape(v)
      v.gsub(/([ \n\\])/,'\\\\\\1')
    end
  end

  def self.apply(builder, env)
    unless env.kind_of? Hash
      raise FPM::Fry::WithData(
        ArgumentError.new("ENV must be a Hash, got #{env.inspect}"),
        documentation: 'https://github.com/xing/fpm-fry/wiki/Plugin-env'
      )
    end
    env.each do |k,v|
      k = k.to_s if k.kind_of? Symbol
      unless k.kind_of?(String) && k =~ /\A[A-Z][A-Z0-9_]*\z/
        raise FPM::Fry::WithData(
          ArgumentError.new("environment variable names must be strings consisiting of uppercase letters, numbers and underscores, got #{k.inspect}"),
          documentation: 'https://github.com/xing/fpm-fry/wiki/Plugin-env'
        )
      end
    end
    builder.recipe.dockerfile_hooks << AddEnv.new(env.dup.freeze)
  end

end
