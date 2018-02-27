name 'crank'
version '0.1.5+git'

source  'git@github.com:pusher/crank.git',
  to: "src/github.com/pusher/crank"

build_depends 'wget'
build_depends 'ruby'
build_depends 'bundler'

plugin 'env',
  GOPATH: '/tmp/build',
  PATH: '/usr/local/go/bin:$PATH'

# Things you do in before_build do not end up in the final package.
before_build do
  # Install custom go because we can
  run 'wget','https://storage.googleapis.com/golang/go1.5.linux-amd64.tar.gz'
  run 'tar','-C','/usr/local','-xzf','go1.5.linux-amd64.tar.gz'
  # Get go and ruby deps
  run 'bundle','install'
  run 'go', 'get', '-d', './...'
end
run 'bundle', 'exec', 'rake'
run 'make'
run 'make', 'install'
