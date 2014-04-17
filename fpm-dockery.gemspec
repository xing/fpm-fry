Gem::Specification.new do |gem|
  gem.name    = 'fpm-dockery'
  gem.version = '0.1.0'
  gem.date    = Time.now.strftime("%Y-%m-%d")

  gem.summary = "FPM Dockery"

  gem.description = 'packages docker changes with fpm'

  gem.authors  = ['Hannes Georg']
  gem.email    = 'hannes.georg@xing.com'
  gem.homepage = 'https://github.com/xing/fpm-dockery'

  gem.license  = 'MIT'

  gem.bindir   = 'bin'
  gem.executables << 'fpm-dockery'

  # ensure the gem is built out of versioned files
  gem.files = Dir['lib/**/*'] & `git ls-files -z`.split("\0")

  gem.add_dependency 'excon', '~> 0.30'
  gem.add_dependency 'fpm', '~> 1.0'

end
