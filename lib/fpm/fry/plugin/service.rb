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

    # @return [Hash<String,Tuple<Numeric,Numeric>]
    attr :limits

    # @api private
    def initialize(name)
      @name = name
      @command = []
      @limits = {}
      @user = nil
      @group = nil
      @chdir = nil
    end

    # @overload name
    #   @return [String] this service's name
    # @overload name( name )
    #   @param  [String] name new name for this service
    #   @return [String] this service's name
    def name( name = nil )
      if name
        @name = name
      end
      return @name
    end

    # @overload group
    #   @return [String] the linux user group this service should run as
    # @overload group( name )
    #   @param  [String] name new linux user group this service should run as
    #   @return [String] the linux user group this service should run as
    def group( group = nil )
      if group
        @group = group
      end
      return @group
    end

    # @overload user
    #   @return [String] the linux user this service should run as
    # @overload user( name )
    #   @param  [String] name new linx user this service should run as
    #   @return [String] the linux user this service should run as
    def user( n = nil )
      if n
        @user = n
      end
      return @user
    end

    # Sets a limit for this service. Valid limits are:
    #  
    #   - core
    #   - cpu
    #   - data
    #   - fsize
    #   - memlock
    #   - msgqueue
    #   - nice
    #   - nofile
    #   - nproc
    #   - rss
    #   - rtprio
    #   - sigpending
    #   - stack
    # 
    # @see http://linux.die.net/man/5/limits.conf Limits.conf manpage for limits and their meanings.
    # @param [String] name see above list for valid limits
    # @param [Numeric,"unlimited"] soft soft limit
    # @param [Numeric,"unlimited"] hard hard limit
    def limit( name, soft, hard = soft )
      unless LIMITS.include? name
        raise ArgumentError, "Unknown limit #{name.inspect}. Known limits are: #{LIMITS.inspect}"
      end
      @limits[name] = [soft,hard]
      return nil
    end

    # @overload chdir
    #   @return [String,nil] working directory of the service
    # @overload chdir( dir )
    #   @param  [String] dir new working directory of the service
    #   @return [String] working directory of the service
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
      init = builder.plugin('init')
      if init.systemd?
        add_systemd!(builder)
      elsif init.upstart?
        add_upstart!(builder)
      elsif init.sysv?
        add_sysv!(builder)
      end
    end
  private
    def add_upstart!(builder)
      init = builder.plugin('init')
      edit = builder.plugin('edit_staging')
      env = Environment.new(name, command, "", @limits, @user, @group, @chdir)
      edit.add_file "/etc/init/#{name}.conf",StringIO.new( env.render('upstart.erb') )
      if init.with? :sysvcompat
        edit.ln_s init.with[:sysvcompat], "/etc/init.d/#{name}"
      end
      builder.plugin('script_helper') do |sh|
        sh.after_install_or_upgrade(<<BASH)
if status #{Shellwords.shellescape name} 2>/dev/null | grep -q ' start/'; then
# It has to be stop+start because upstart doesn't pickup changes with restart.
if which invoke-rc.d >/dev/null 2>&1; then
  invoke-rc.d #{Shellwords.shellescape name} stop
else
  stop #{Shellwords.shellescape name}
fi
fi
if which invoke-rc.d >/dev/null 2>&1; then
invoke-rc.d #{Shellwords.shellescape name} start
else
start #{Shellwords.shellescape name}
fi
BASH
        sh.before_remove_entirely(<<BASH)
if status #{Shellwords.shellescape name} 2>/dev/null | grep -q ' start/'; then
stop #{Shellwords.shellescape name}
fi
BASH
      end
      builder.plugin('config', FPM::Fry::Plugin::Config::IMPLICIT => true) do |co|
        co.include "etc/init/#{name}.conf"
      end
    end

    def add_sysv!(builder)
      edit = builder.plugin('edit_staging')
      env = Environment.new(name, command, "", @limits, @user, @group, @chdir)
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
    end

    def add_systemd!(builder)
      edit = builder.plugin('edit_staging')
      env = Environment.new(name, command, "", @limits, @user, @group, @chdir)
      edit.add_file "/lib/systemd/system/#{name}.service", StringIO.new( env.render('systemd.erb') ), chmod: '644'
      builder.plugin('script_helper') do |sh|
        sh.after_install_or_upgrade(<<BASH)
systemctl preset #{Shellwords.shellescape name}.service
if systemctl is-enabled --quiet #{Shellwords.shellescape name}.service ; then
systemctl --system daemon-reload
systemctl restart #{Shellwords.shellescape name}.service
fi
BASH
        sh.before_remove_entirely(<<BASH)
systemctl disable --now #{Shellwords.shellescape name}.service
BASH

      end
    end

  end

  def self.apply(builder, &block)
    d = DSL.new(builder.name)
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

