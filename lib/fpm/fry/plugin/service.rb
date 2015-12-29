require 'fpm/fry/plugin'
require 'fpm/fry/plugin/init'
require 'fpm/fry/plugin/edit_staging'
require 'fpm/fry/plugin/config'
require 'erb'
require 'shellwords'
module FPM::Fry::Plugin ; module Service

  class Environment < Struct.new(:name,:command, :description, :limits, :user, :group, :chdir)

    def render(file)
      _erbout = ""
      erb = ERB.new(
        IO.read(File.join(File.dirname(__FILE__),'..','templates',file)),
        0, "-"
      )
      eval(erb.src,nil,File.join(File.dirname(__FILE__),'..','templates',file))
      return _erbout
    end

  end

  LIMITS = %w(core cpu data fsize memlock msgqueue nice nofile nproc rss rtprio sigpending stack)

  class DSL

    attr :limits

    def initialize(*_)
      super
      @name = nil
      @command = []
      @limits = {}
      @user = nil
      @group = nil
      @chdir = nil
    end

    def name( n = nil )
      if n
        @name = n
      end
      return @name
    end

    def group( n = nil )
      if n
        @group = n
      end
      return @group
    end

    def user( n = nil )
      if n
        @user = n
      end
      return @user
    end

    def limit( name, soft, hard = soft )
      unless LIMITS.include? name
        raise ArgumentError, "Unknown limit #{name.inspect}. Known limits are: #{LIMITS.inspect}"
      end
      @limits[name] = [soft,hard]
    end

    def chdir( dir = nil )
      if dir
        @chdir = dir
      end
      @chdir
    end

    def command( *args )
      if args.any?
        @command = args
      end
      return @command
    end

    # @api private
    def add!(builder)
      name = self.name || builder.name || raise
      init = Init.detect_init(builder.variables)
      edit = builder.plugin('edit_staging')
      env = Environment.new(name, command, "", @limits, @user, @group, @chdir)
      case(init)
      when 'upstart' then
        edit.add_file "/etc/init/#{name}.conf",StringIO.new( env.render('upstart.erb') )
        edit.ln_s '/lib/init/upstart-job', "/etc/init.d/#{name}"
        builder.plugin('script_helper') do |sh|
          sh.after_install_or_upgrade(<<BASH)
if status #{Shellwords.shellescape name} 2>/dev/null | grep -q ' start/'; then
  # It has to be stop+start because upstart doesn't pickup changes with restart.
  stop #{Shellwords.shellescape name}
fi
start #{Shellwords.shellescape name}
BASH
          sh.before_remove_entirely(<<BASH)
if status #{Shellwords.shellescape name} 2>/dev/null | grep -q ' start/'; then
  stop #{Shellwords.shellescape name}
fi
BASH
        end
        builder.plugin('config', FPM::Fry::Plugin::Config::IMPLICIT => true) do |co|
          co.include "etc/init/#{name}.conf"
          co.include "etc/init.d/#{name}"
        end
      when 'sysv' then
        edit.add_file "/etc/init.d/#{name}",StringIO.new( env.render('sysv.erb') ), chmod: '750'
        builder.plugin('script_helper') do |sh|
          sh.after_install_or_upgrade(<<BASH)
update-rc.d #{Shellwords.shellescape name} defaults
/etc/init.d/#{Shellwords.shellescape name} restart
BASH
          sh.before_remove_entirely(<<BASH)
/etc/init.d/#{Shellwords.shellescape name} stop
update-rc.d -f #{Shellwords.shellescape name} remove
BASH
        end
        builder.plugin('config', FPM::Fry::Plugin::Config::IMPLICIT => true) do |co|
          co.include "etc/init.d/#{name}"
        end
      when 'systemd' then

      end
    end

  end

  def self.apply(builder, &block)
    d = DSL.new
    if !block
      raise ArgumentError, "service plugin requires a block"
    elsif block.arity == 1
      block.call(d)
    else
      d.instance_eval(&block)
    end
    d.add!(builder)
    return nil
  end

end end

