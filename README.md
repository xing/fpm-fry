fpm-fry
======================

[![Build Status](https://travis-ci.org/xing/fpm-fry.svg?branch=master)](https://travis-ci.org/xing/fpm-fry)
[![Coverage Status](https://coveralls.io/repos/xing/fpm-fry/badge.svg?branch=master&service=github)](https://coveralls.io/github/xing/fpm-fry?branch=master)
[![Doc Coverage](https://inch-ci.org/github/xing/fpm-fry.svg?branch=master)](https://inch-ci.org/github/xing/fpm-fry)

[fpm-cookery](https://github.com/bernd/fpm-cookery) inspired package builder on [docker](https://docker.io)

What does it do?
-----------------

- simplifies building rpm and deb packages
- lightweight isolated builds
- build information in files so you can check them into git
- simple hackable ruby code

Installation
-----------------

    $> gem install fpm-fry

You also need a running a machine running docker >= 1.8. This does not need to be the same machine, fpm-fry can
use the docker remote api. See [the docker install guide](https://www.docker.io/gettingstarted/?#h_installation).

Introduction
---------------

fpm-fry like fpm-cookery works with recipe files. A recipe file can look like this:

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

If you don't tell fpm-fry which recipe to use it will look for a file called `recipe.rb` in the current directory.

Unlike fpm-cookery fpm-fry needs to know additionally which docker image it should use to build ( `ubuntu:precise` in this example ).
fpm-fry does not pull this image into the docker instance, you have to make sure that it's present and valid ( do `docker pull ubuntu:precise` before you try something ).

To build your first package type:

    $> fpm-fry cook ubuntu:precise recipe.rb


Recipe syntax
-------------------------

Recipe are ordinary ruby code. They are evaled inside an FPM::Fry::Recipe::Builder which gives you the following methods:

### General stuff

- `name String`: Sets the package name. This is the only mandatory setting.

```ruby
name "my-awesome-package"
```

- `version String`: Sets the package version.

```ruby
version "1.2.3"
```

- `depends String, ConstraintsOrOptions = {}`: Adds a dependency. Available options are:
    - `install: true|false|String`: Sets if this package is installed during build. You can override the package actually installed by passing a string. This way you can depend on virtual packages but install a real package for building.
    - `constraints: String|Array`: Specifies a required version. Required versions are currently not honored for build dependencies.

```ruby
depends "other-package"
depends "virtual-package", install: "real-package"
depends "mock-package", install: false
depends "mock-package", constraints: "0.0.1"
depends "mock-package", constraints: ">= 0.0.1"
# These three lines are all equal:
depends "mock-package", ">= 0.0.1, << 0.1.0"
depends "mock-package", constraints: ">= 0.0.1, << 0.1.0"
depends "mock-package", constraints: [">= 0.0.1", "<< 0.1.0"]
```

- `source Url, Options = {}`: Sets the source url to use for this package. Out-of-the-box the following types are supported:

**https**: Just pass an http url.

```ruby
source "https://example.com/path/source.tar.gz",
  checksum: "DEADBEEEEEEEEEEEEEEEF" # checksum is md5/sha1/sha256/sha512 based on the length of the checksum
```

Files ending in .tar, .tar.gz, .tgz, .tar.bz2 and .zip will be extracted. Files ending in .bin and .bundle will be placed in the container as is.

**git**: Understands any url that git understands. Requires git on your system.

```ruby
source "http://github.com/user/repo.git" # Use HEAD
source "http://github.com/user/repo.git", branch: "foo" # Use branch foo
source "http://github.com/user/repo.git", tag: "0.1.0" # Use tag 0.1.0
```

**dir**: Uses a directory on _your_ machine.

```ruby
source "./src" # Relative to recipe file
```

- `run String, *String`: Run the given command during build. All parts are automatically shellescaped.

```ruby
run "./configure","--prefix=/foo/bar"
run "make"
run "make", "INSTALL"
```

- `bash String?, String`: Run arbitrary bash code during build. This method is intended as an interface for plugins.

```ruby
bash "echo 'this works' >> file"
bash "This name will be displayed in the output log", "some code here"
```

- `after_install String`: adds a script that gets run after installation of this package.

```ruby
after_install <<BASH
#!/bin/bash
echo "lol"
BASH
```

- `before_build` runs all comamnds before the actual build happens ( since 0.2.1, experimental )

```ruby
before_build do
  run "gem","install","
end
```

Scripts running inside `before_install` modify the base image instead of the package. This is the ideal place to install build dependencies that are not linux packages ( gems, jars, eggs, ... ).


- `add` mount a file or directoy from the build environment into the build container (corresponds to ADD directive in a Dockerfile)

```ruby
add "images/code/install-code.sh", ".install-code.sh"
```

Mounts are added before any other build command runs in the build container.


### Target info

- `flavour`: Returns the linux family like "redhat" or "debian"
- `distribution`: Returns the linux distribution like "ubuntu" or "centos"
- `release`: The distribution version as a string like "12.04" or "6.0.7"
- `codename`: The release codename like "squeeze" or "trusty"

### Plugins

fpm-fry has a tiny but powerful plugin architecture.

- `plugin String, *Args`: loads and enables the given plugin with the given arguments.

fpm-fry ships with these plugins:

#### exclude

Allows you to exclude files present after build from the final package.

```ruby

plugin "exclude"

exclude "foo/**/bar"
```

#### platforms

Adds a syntactic sugar for platform filters.

```ruby
plugin "platforms"
platforms :ubuntu do
  # ubuntu stuff here
end
```

#### service

Adds a service inluding an init script, an upstart script and the correct install hooks.

```ruby
plugin "service" do
  name "my-service"
  command "/usr/bin/my-service","-f" # command is expected to stay in foreground
  user "my-user" # optional
  group "my-group" # optional
end
```

#### user

Adds a configure script adding the given user.

```ruby
plugin "user", "my-user"
```

#### apt

Adds an apt repository ( experimental ).

```ruby
plugin 'apt' do |apt|
  apt.repository "https://repo.varnish-cache.org/#{distribution}", codename, "varnish-4.1"
end
```

Multi-Package support
-------------------------

You can build multiple packages from a single recipe. To do so add `package` blocks inside the recipe.

```ruby
name 'mainpackage'
version '1.3.7'

package 'subpackage' do
  # subpackages implictly inherit the version
  # version '1.3.7'

  # add a dependency on the mainpackage with the exact same version:
  depends 'mainpackage', version

  # tell fry which files should go in the subpackage
  files '/usr/bin/awesome'
end
```

Subpackages must contain at least one `files` option so the build process knows where a file belongs. All
other files are implictly put in the main package.

Subpackage can make use of plugins like `service`, too. They can furthermore depend on each other without
disturbing the build process.


Building on remote hosts
-------------------------

fpm-fry like docker respects the `DOCKER_HOST` environment variable. So if you have docker server `docker.example.com` listening on port 4243 you can set `DOCKER_HOST` to `tcp://docker.example.com:4243`.

You don't even need to have the docker command on your local machine. fpm-fry does all the interaction with docker on it's own.

Bonus
-------------------------

You can also package container changes directly.

1. Create a docker container with the files you need

        $> docker run -t -i stackbrew/ubuntu:precise /bin/bash
        root@fce49040a269:/# mkdir bla
        root@fce49040a269:/# echo "Hello World" > /bla/foo
        root@fce49040a269:/# exit

2. Package it using all the fpm stuff you like

        $> fpm-fry fpm -sdocker -tdeb -nbla fce49040a269
        Created deb package {:path=>"bla_1.0_amd64.deb"}

3. Check the result

        $> dpkg-deb --contents bla_1.0_amd64.deb
        drwx------ 0/0               0 2014-03-12 15:35 ./
        drwxr-xr-x 0/0               0 2014-03-12 15:35 ./bla/
        -rw-r--r-- 0/0               0 2014-03-12 15:35 ./bla/foo

Authors
------------------

- Maxime Lagresle [@maxlaverse](https://github.com/maxlaverse)
- Stefan Kaes [@skaes](https://github.com/skaes)
- Sebastian Brandt [@sebbrandt87](https://github.com/sebbrandt87)
- Hannes Georg [@hannesg](https://github.com/hannesg)

License
-----------------

The MIT License (MIT)

Copyright (c) 2018 XING AG

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
