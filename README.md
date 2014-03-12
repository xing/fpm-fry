fpm-dockery
======================

Example
---------------

Create a docker container with the files you need

    $> docker run -t -i stackbrew/ubuntu:precise /bin/bash
    root@fce49040a269:/# mkdir bla
    root@fce49040a269:/# echo "Hello World" > /bla/foo
    root@fce49040a269:/# exit

Package it using all the fpm stuff you like

    $> fpm-dockery -sdocker -tdeb -nbla fce49040a269
    Created deb package {:path=>"bla_1.0_amd64.deb"}

Check the result

    $> dpkg-deb --contents bla_1.0_amd64.deb
    drwx------ 0/0               0 2014-03-12 15:35 ./
    drwxr-xr-x 0/0               0 2014-03-12 15:35 ./bla/
    -rw-r--r-- 0/0               0 2014-03-12 15:35 ./bla/foo
