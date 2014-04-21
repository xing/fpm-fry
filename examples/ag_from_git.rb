name 'ag'
version '0.21.0'

source 'https://github.com/ggreer/the_silver_searcher.git', tag: version

if flavour == 'redhat'
  build_depends 'pkgconfig'
  build_depends 'automake'
  build_depends 'gcc'
  build_depends 'zlib-devel'
  build_depends 'pcre-devel'
  build_depends 'xz-devel'

  depends 'zlib'
  depends 'xz'
  depends 'zlib'
elsif flavour == 'debian'
  build_depends 'automake'
  build_depends 'pkg-config'
  build_depends 'libpcre3-dev'
  build_depends 'zlib1g-dev'
  build_depends 'liblzma-dev'
  build_depends 'make'

  depends 'libc6'
  depends 'libpcre3'
  depends 'zlib1g'
  depends 'liblzma5'
end

run './build.sh'
run 'make', 'install'
