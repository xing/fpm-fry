require 'fpm/dockery/plugin'
module FPM::Dockery::Plugin::ScriptHelper

  class Script

    attr :renderer

    def initialize(renderer)
      @renderer = renderer
    end

    def to_s
      renderer.call(self)
    end

    def name
      self.class.name.split('::').last.gsub(/([^A-Z])([A-Z])/,'\1_\2').downcase
    end
  end

  module RenderErb
    def render_path(script, path)
      _erbout = ""
      erb = ERB.new(
        IO.read(File.join(File.dirname(__FILE__),'..','templates',path, "#{script.name}.erb"))
      )
      script.instance_eval(erb.src)
      return _erbout
    end
  end

  module DebianRenderer
    extend RenderErb
    def self.call(script)
      render_path(script,'debian')
    end
  end

  module RedhatRenderer
    extend RenderErb
    def self.call(script)
      render_path(script,'redhat')
    end
  end

  class BeforeInstall < Script

    # deb: $1 == install
    # rpm: $1 == 1
    attr :install

    # deb: $1 == upgrade
    # rpm: $1 >= 2
    attr :upgrade

    def initialize(*_)
      super
      @install = []
      @upgrade = []
    end

  end

  class AfterInstall < Script

    def initialize(*_)
      super
      @configure = []
    end

    # deb: $1 == configure
    # rpm: -always-
    attr :configure

  end

  class BeforeRemove < Script

    def initialize(*_)
      super
      @remove = []
      @upgrade = []
    end

    # deb: $1 == remove
    # rpm: $1 == 0
    attr :remove

    # deb: $1 == upgrade
    # rpm: $1 >= 1
    attr :upgrade

  end

  class AfterRemove < Script

    def initialize
      @remove = []
      @upgrade = []
    end

    # deb: $1 == upgrade
    # rpm: $1 == 1
    attr :upgrade

    # deb: $1 == remove
    # rpm: $1 == 0
    attr :remove

  end

  NAME_TO_SCRIPT = {
    before_install: BeforeInstall,
    after_install: AfterInstall,
    before_remove: BeforeRemove,
    after_remove: AfterRemove
  }

  SCRIPT_TO_NAME = NAME_TO_SCRIPT.invert

  class DSL < Struct.new(:builder)

# before(install) => before_install:install
# before(upgrade) => before_install:upgrade
# after(install_or_upgrade) => after_install:configure
# before(remove_for_upgrade) => before_remove:upgrade
# before(remove) => before_remove:remove
# after(remove) => after_remove:remove
# after(remove_for_upgrade) => after_remove:upgrade

    def after_install_or_upgrade(*scripts)
      find(:after_install).configure.push(*scripts)
    end

    def before_remove_entirely(*scripts)
      find(:before_remove).remove.push(*scripts)
    end

    def after_remove_entirely(*scripts)
      find(:after_remove).remove.push(*scripts)
    end
  private

    def find(type)
      klass = NAME_TO_SCRIPT[type]
      script = builder.recipe.scripts[type].find{|s| s.kind_of? klass }
      if script.nil?
        script = klass.new( renderer )
        builder.recipe.scripts[type] << script
      end
      return script
    end

    def renderer
      @renderer ||= case(builder.flavour)
                    when 'debian' then DebianRenderer
                    when 'redhat' then RedhatRenderer
                    else
                      raise "Unknown flavour: #{builder.flavour.inspect}"
                    end
    end

  end

  def self.apply(builder, options = {}, &block)
    dsl = DSL.new(builder)
    if block
      if block.arity == 1 
        yield dsl
      else
        dsl.instance_eval(&block)
      end
    end
  end

end
