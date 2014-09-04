fpm-dockery
======================

[fpm-cookery](https://github.com/bernd/fpm-cookery) inspired package builder on [docker](https://docker.io)

What does it do?
-----------------

- simplifies building rpm and deb packages
- lightweight isolated builds
- build information in files so you can check them into git
- simple hackable ruby code

Installation
-----------------

    $> gem install fpm-dockery

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
fpm-dockery does not pull this image into the docker instance, you have to make sure that it's present and valid ( do `docker pull ubuntu:precise` before you try something ).

To build your first package type:

    $> fpm-dockery cook ubuntu:precise recipe.rb


Recipe syntax
-------------------------

Recipe are ordinary ruby code. They are evaled inside an FPM::Dockery::Recipe::Builder which gives you the following methods:

### General stuff

- `name String`: Sets the package name. This is the only mandatory setting.

```ruby
name "my-awesome-package"
```

- `version String`: Sets the package version.

```ruby
version "1.2.3"
```

- `depends String, Options = {}`: Adds a dependency. Available options are:
    - `install: true|false|String`: Sets if this package is installed during build. You can override the package actually installed by passing a string. This way you can depend on virtual packages but install a real package for building.

```ruby
depends "other-package"
depends "virtual-package", install: "real-package"
depends "mock-package", install: false
```

- `source Url, Options = {}`: Sets the source url to use for this package. Out-of-the-box the following types are supported:
    - **tar file**: Just pass an url to a tar file.

```ruby
source "https://example.com/path/source.tar.gz",
  checksum: "DEADBEEEEEEEEEEEEEEEF" # checksum is sha256
```

    - **git**: Understands any url that git understands. Requires git on your system.

```ruby
source "http://github.com/user/repo.git" # Use HEAD
source "http://github.com/user/repo.git", branch: "foo" # Use branch foo
source "http://github.com/user/repo.git", tag: "0.1.0" # Use tag 0.1.0
```

    - **dir**: Uses a directory on _your_ machine.

```ruby
source "./src" # Relative to recipe file
```

- `run String, *String`: Run the given command during build. All parts are automatically shellescaped.

```ruby
run "./configure","--prefix=/foo/bar"
run "make"
run "make", "INSTALL"
```

- `after_install String`: adds a script that gets run after installation of this package.

```ruby
after_install <<BASH
#!/bin/bash
echo "lol"
BASH
```

### Target info

- `flavour`: Returns the linux family like "redhat" or "debian"
- `distribution`: Returns the linux distribution like "ubuntu" or "centos"
- `distribution_version`: The distribution version as a string like "12.04" or "6.0.7"
- `codename`: The release codename like "squeeze" or "trusty"

Building on remote hosts
-------------------------

fpm-dockery like docker respects the `DOCKER_HOST` environment variable. So if you have docker server `docker.example.com` listening on port 4243 you can set `DOCKER_HOST` to `tcp://docker.example.com:4243`.

You don't even need to have the docker command on your local machine. fpm-dockery does all the interaction with docker on it's own.

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

Authors
------------------

Hannes Georg @hannesg42

License
-----------------

The MIT License (MIT)

Copyright (c) 2014 XING AG

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
