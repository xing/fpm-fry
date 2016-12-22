# Tested with these images:
# - ubuntu:16.04

name 'curl'
version '7.51.0'

source "http://curl.haxx.se/download/curl-#{version}.tar.gz",
  checksum: '65b5216a6fbfa72f547eb7706ca5902d7400db9868269017a8888aa91d87977c'

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
depends       'librtmp1'
build_depends 'librtmp-dev'

run './buildconf'
run './configure'
run 'make'
run 'make', 'install'
