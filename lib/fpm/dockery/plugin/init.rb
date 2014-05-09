require 'fpm/dockery/plugin'
module FPM::Dockery::Plugin::Init

  def self.detect_init(variables)
    if variables[:init]
      return variables[:init]
    end
    d = variables[:distribution]
    v = variables[:distribution_version].split('.').map(&:to_i)
    case(d)
    when 'debian'
      if v[0] < 8
        return 'sysv'
      else
        return 'systemd'
      end
    when 'ubuntu'
      if v[0] <= 14 && v[1] < 10
        return 'upstart'
      else
        return 'systemd'
      end
    when 'centos','redhat'
      if v[0] <= 5
        return 'sysv'
      elsif v[0] == 6
        return 'upstart'
      else
        return 'systemd'
      end
    else
      raise "Unknown init system for #{d} #{v.join '.'}"
    end
  end

  def init(*inits)
    inits = inits.flatten.map(&:to_s)
    actual = FPM::Dockery::Plugin::Init.detect_init(variables)
    if inits.none?
      return actual
    elsif inits.include? actual
      if block_given?
        yield
      else
        return true
      end
    else
      return false
    end
  end


end
