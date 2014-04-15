fpm-dockery
======================

[fpm-cookery](https://github.com/bernd/fpm-cookery) inspired package builder on [docker](https://docker.io)

Installation
-----------------

    gem install fpm-dockery

You also need a running a machine running docker. This does not need to be the same machine, fpm-dockery can 
use the docker remote api. See [the docker install guide](https://www.docker.io/gettingstarted/?#h_installation).

Introduction
---------------

fpm-dockery like fpm-cookery works with recipe files. A recipe file can look like this:

```ruby
    name 'ag'
    version '0.21.0'
    
    source 'https://github.com/ggreer/the_silver_searcher/archive/0.21.0.tar.gz',
      checksum: 'ee921373e2bb1a25c913b0098ab946d137749b166d340a8ae6d88a554940a793',
      file_map: {"the_silver_searcher-#{version}" => '.'}
    
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
```

Recipe files contains informations about the used sources, required software packages and build steps.

If you don't tell fpm-dockery which recipe to use it will look for a file called `recipe.rb` in the current directory.

Unlike fpm-cookery fpm-dockery needs to know additionally which docker image it should use to build ( `ubuntu:precise` in this example ).

To build your first package type:

    fpm-dockery cook ubuntu:precise


Bonus
-------------------------

You can also package container changes directly.

1. Create a docker container with the files you need

    $> docker run -t -i stackbrew/ubuntu:precise /bin/bash
    root@fce49040a269:/# mkdir bla
    root@fce49040a269:/# echo "Hello World" > /bla/foo
    root@fce49040a269:/# exit

2. Package it using all the fpm stuff you like

    $> fpm-dockery fpm -sdocker -tdeb -nbla fce49040a269
    Created deb package {:path=>"bla_1.0_amd64.deb"}

3. Check the result

    $> dpkg-deb --contents bla_1.0_amd64.deb
    drwx------ 0/0               0 2014-03-12 15:35 ./
    drwxr-xr-x 0/0               0 2014-03-12 15:35 ./bla/
    -rw-r--r-- 0/0               0 2014-03-12 15:35 ./bla/foo
