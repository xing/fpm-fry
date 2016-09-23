require 'fpm/fry/plugin'
# A plugin that detects the init system of a docker image.
#
# This plugin is a low-level plugin and is used by other plugins such as "service".
#
# @example in a recipe when using the image "ubuntu:16.04"
#   plugin 'init'
#   init.systemd? #=> true
#   init.sysv? #=> false
module FPM::Fry::Plugin::Init

  # Contains information about the init system in use.
  class System < Struct.new(:name, :with)
    def ==(other)
      case(other)
      when String,Symbol
        return name.to_s == other.to_s
      end
      super
    end
    def ===(other)
    case(other)
      when String,Symbol
        return name.to_s == other.to_s
      end
      super
    end
    def with?(feature)
      !!with[feature]
    end
    def sysv?
      name == :sysv
    end
    def upstart?
      name == :upstart
    end
    def systemd?
      name == :systemd
    end
  end

  # @overload init
  #   @return [System] initsystem in use
  # @overload init(*inits)
  #   @example
  #     init("sysv") do
  #       # do something only for sysv
  #     end
  #   @param [Array<String>] inits
  #   @yield when the initsystem is in inits param
  #   @return [true] when the initsystem is in inits arguments
  #   @return [false] otherwise
  #
  def init(*inits)
    inits = inits.flatten.map(&:to_s)
    if inits.none?
      return @init
    elsif inits.include? @init
      if block_given?
        yield
      end
      return true
    else
      return false
    end
  end

private
  def self.detect(inspector)
    if inspector.link_target('/sbin/init') == '/lib/systemd/systemd'
      return System.new(:systemd, {})
    end
    if inspector.exists?('/etc/init')
      return detect_upstart(inspector)
    end
    if inspector.exists?('/etc/init.d')
      return detect_sysv(inspector)
    end
    return nil
  end

  def self.detect_upstart(inspector)
    features = {
      sysvcompat: inspector.exists?('/lib/init/upstart-job') ? '/lib/init/upstart-job' : false
    }
    return System.new(:upstart,features)
  end

  def self.detect_sysv(inspector)
    features = {
      chkconfig: inspector.exists?('/sbin/chkconfig'),
      'update-rc.d': inspector.exists?('/usr/sbin/update-rc.d'),
      'invoke-rc.d': inspector.exists?('/usr/sbin/invoke-rc.d')
    }
    return System.new(:sysv,features)
  end

  def self.extended(base)
    base.instance_eval do
      @init = FPM::Fry::Plugin::Init.detect(inspector)
    end
  end

  def self.apply(builder)
    builder.extend(self)
    return builder.init
  end

end
