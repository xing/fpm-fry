name 'ag'
version '0.21.0'

source 'https://github.com/ggreer/the_silver_searcher/archive/0.21.0.tar.gz',
  checksum: 'ee921373e2bb1a25c913b0098ab946d137749b166d340a8ae6d88a554940a793',
  file_map: {"the_silver_searcher-#{version}" => '.'}

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

run './build.sh'
run 'make', 'install'
