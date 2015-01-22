require 'fpm/dockery/plugin'
require 'fpm/dockery/plugin/init'
require 'fpm/dockery/plugin/edit_staging'
require 'erb'
require 'shellwords'
module FPM::Dockery::Plugin ; module Service

  class Environment < Struct.new(:name,:command, :description)

    def render(file)
      _erbout = ""
      erb = ERB.new(
        IO.read(File.join(File.dirname(__FILE__),'..','templates',file))
      )
      eval(erb.src)
      return _erbout
    end

  end

  class DSL

    def initialize(*_)
      super
      @name = nil
      @command = []
    end

    def name( n = nil )
      if n
        @name = n
      end
      return @name
    end

    def command( *args )
      if args.any?
        @command = args
      end
      return @command
    end

    # @api private
    def add!(builder)
      recipe = builder.recipe
      name = self.name || recipe.name || raise
      init = Init.detect_init(builder.variables)
      edit = EditStaging::DSL.new(recipe)
      env = Environment.new(name, command, "")
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

