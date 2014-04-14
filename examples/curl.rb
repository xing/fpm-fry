name 'curl'
version '7.36.0'

source 'http://curl.haxx.se/download/curl-7.36.0.tar.gz',
  checksum: '33015795d5650a2bfdd9a4a28ce4317cef944722a5cfca0d1563db8479840e90',
  file_map: {"curl-#{version}" => '.'}

build_depends 'autoconf'
build_depends 'libtool'
build_depends 'build-essential'

# Ares support
depends       'libc-ares2'
build_depends 'libc-ares-dev'
# IDN support
depends       'libidn11'
build_depends 'libidn11-dev'
# krb support
depends       'libgssapi-krb5-2'
build_depends 'krb5-multidev'
# ldap support
depends       'libldap-2.4-2'
build_depends 'libldap2-dev'
# rtmp support
depends       'librtmp0'
build_depends 'librtmp-dev'

run './buildconf'
run './configure'
run 'make'
run 'make', 'install'
