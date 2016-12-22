name 'redis'
version '3.2.5'

source "http://download.redis.io/releases/redis-#{version}.tar.gz",
  checksum: '6f6333db6111badaa74519d743589ac4635eba7a'

build_depends 'build-essential'

# Creates user "redis" and group "redis"
plugin 'user', 'redis', group: true

package 'redis-server' do

  depends 'redis', version

  # Create the lib directory
  plugin 'script_helper' do
    after_install_or_upgrade <<BASH
mkdir -p /var/lib/redis
chown redis:redis /var/lib/redis
BASH
  end

  # Create a redis service
  plugin 'service' do
    name    'redis'
    command '/usr/local/bin/redis-server'
    user    'redis'
    group   'redis'
    chdir    '/var/lib/redis'
  end
end

package 'redis-sentinel' do

  depends 'redis', version

  files '/usr/local/bin/redis-sentinel'

  plugin 'service' do
    command '/usr/local/bin/redis-sentinel'
    user    'redis'
    group   'redis'
  end

end

package 'redis-utils' do

  files '/usr/local/bin/redis-benchmark'
  files '/usr/local/bin/redis-check-dump'
  files '/usr/local/bin/redis-check-aof'

end

run 'make'
run 'make', 'install'
