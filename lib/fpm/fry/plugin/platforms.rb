module FPM::Fry::Plugin::Platforms

  def platforms(platform, *platforms)
    p = [platform,platforms].flatten.map(&:to_s)
    if p.include? distribution
      yield
    end
  end

end
