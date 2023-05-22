Gem::Specification.new do |gem|
  gem.name    = 'fpm-fry'
  gem.version = '0.6.3'
  gem.date    = Time.now.strftime("%Y-%m-%d")

  gem.summary = "FPM Fry"

  gem.description = 'deep-fried package builder'

  gem.authors  = [
    'Maxime Lagresle',
    'Stefan Kaes',
    'Sebastian Brandt',
    'Hannes Georg',
    'Julian Tabel',
    'Dennis Konert'
  ]
  gem.email    = 'dennis.konert@new-work.se'
  gem.homepage = 'https://github.com/xing/fpm-fry'

  gem.license  = 'MIT'

  gem.bindir   = 'bin'
  gem.executables << 'fpm-fry'

  # ensure the gem is built out of versioned files
  gem.files = Dir['lib/**/*'] & `git ls-files -z`.split("\0")

  gem.add_dependency 'excon', '~> 0.71'
  gem.add_dependency 'fpm', '~> 1.13'

  gem.add_development_dependency 'rake', '~> 12.0'
  gem.add_development_dependency 'rspec', '~> 3.0', '>= 3.0.0'
  gem.add_development_dependency 'webmock', '~> 3.0'
  gem.add_development_dependency 'coveralls', '>= 0.8.23'
  gem.add_development_dependency 'simplecov', '>= 0'
end
