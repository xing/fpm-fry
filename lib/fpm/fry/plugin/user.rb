require 'fpm/fry/plugin'
module FPM::Fry::Plugin ; module User

  def self.apply(builder, name, options = {}, &block)
    cmd = ["adduser", "--system"]
    case options[:group]
    when String
      cmd << '--ingroup' << options[:group]
    when true
      cmd << '--group'
    end
    cmd << name
    builder.plugin('script_helper') do |sh|
      sh.after_install_or_upgrade(Shellwords.shelljoin(cmd))
    end
  end

end ; end
