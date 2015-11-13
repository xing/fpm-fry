name 'redis'
version '3.0.3'

source "http://download.redis.io/releases/redis-#{version}.tar.gz",
  checksum: '1d08fa665b16d0950274dfbd47fbbcf3485e43e901021338640a0334666e9da5',
  file_map: {"redis-#{version}" => ""}

build_depends 'build-essential'

depends 'redis-server', version
depends 'redis-cli', version
depends 'redis-utils', version

plugin 'user', 'redis'

package 'redis-server' do

  files '/usr/local/bin/redis-server'

  plugin 'service' do
    command '/usr/local/bin/redis-server'
    user 'redis'
  end
end

package 'redis-cli' do
  files '/usr/local/bin/redis-cli'
end

package 'redis-sentinel' do

  files '/usr/local/bin/redis-sentinel'
  depends 'redis-server', version

  plugin 'service' do
    command '/usr/local/bin/redis-sentinel'
    user 'redis'
  end

end

package 'redis-utils' do

  files '/usr/local/bin/redis-benchmark'
  files '/usr/local/bin/redis-check-dump'
  files '/usr/local/bin/redis-check-aof'

end

run 'make'
run 'make', 'install'
