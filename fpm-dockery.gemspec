Gem::Specification.new do |gem|
  gem.name    = 'fpm-dockery'
  gem.version = '0.0.1'
  gem.date    = Time.now.strftime("%Y-%m-%d")

  gem.summary = "FPM Dockery"

  gem.description = 'packages docker changes with fpm'

  gem.authors  = ['Hannes Georg']
  gem.email    = 'hannes.georg@googlemail.com'
  gem.homepage = 'https://github.com/hannesg/multi_git'

  gem.license  = 'GPL-3'

  # ensure the gem is built out of versioned files
  gem.files = Dir['lib/**/*'] & `git ls-files -z`.split("\0")

  gem.add_dependency 'ftw'
  gem.add_dependency 'fpm', '>= 1.0.0'

  gem.add_development_dependency "rspec"
end
