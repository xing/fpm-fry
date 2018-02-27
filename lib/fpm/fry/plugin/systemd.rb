require 'fpm/fry/plugin'
require 'fpm/fry/chroot'

# Automatically adds the appropriate maintainer scripts for every systemd unit.
#
# @note experimental
#
# @example in a recipe
#   plugin 'systemd' # no options required, just install your units in /lib/systemd/system
module FPM::Fry::Plugin::Systemd

  # @api private
  VALID_UNITS = /\A[a-z_0-9\-]+@?\.(service|socket|timer)\z/

  # @api private
  INSTANTIATED_UNITS = /\A[a-z_0-9\-]+@\.(service|socket|timer)\z/

  # @api private
  class Callback < Struct.new(:script_helper)

    def call(_, package)
      chroot = FPM::Fry::Chroot.new(package.staging_path)
      files = chroot.entries('lib/systemd/system') - ['.','..']
      valid, invalid = files.partition{|file| VALID_UNITS =~ file }
      if invalid.any?
        package.logger.warning("Found #{invalid.size} files in systemd unit path that are no systemd units", files: invalid)
      end
      units = valid.grep_v(INSTANTIATED_UNITS)
      return if units.none?
      package.logger.info("Added #{units.size} systemd units", units: valid)
      script_helper.after_install_or_upgrade install(units)
      script_helper.before_remove_entirely before_remove(units)
      script_helper.after_remove_entirely after_remove(units)
    end

  private
     def install(units)
<<BASH
if systemctl is-system-running ; then
  systemctl preset #{units.join(' ')}
  if systemctl is-enabled #{units.join(' ')} ; then
    systemctl daemon-reload
    systemctl restart #{units.join(' ')}
  fi
fi
BASH
     end

     def before_remove(units)
<<BASH
if systemctl is-system-running ; then
  systemctl disable --now #{units.join(' ')}
fi
BASH
     end

     def after_remove(units)
<<BASH
if systemctl is-system-running ; then
  systemctl daemon-reload
  systemctl reset-failed #{units.join(' ')}
fi
BASH
     end

  end

  def self.apply(builder)
    return unless builder.plugin('init').systemd?
    builder.plugin('script_helper') do |sh|
      builder.output_hooks << Callback.new(sh)
    end
  end

end
