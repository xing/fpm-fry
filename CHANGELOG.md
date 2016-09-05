# 0.2.2 / 2016.09.05

* [CHANGE] docker minimum version is now 1.8
* [FIX] script_helper plugin: after_remove_entirely broken
* [FEATURE] .tar.bz2 can now be used as source
* [FEATURE] initial systemd support

# 0.2.1 / 2016.04.18

* [FEATURE] Source can now be a plain binary file. The file will be simply fetched and placed in the container verbatim.
* [FIX] Handle dependencies with alternatives during build install
* [FIX] config plugin now issues a warning when a given path is missing
* [FEATURE] `before_build`
* [FIX] config plugin now ignores symlinks #9
* [CHANGE] service plugin now does not mark /etc/init.d/... symlinks as config #9
* [FIX] adding a dependency twice now raises an error #11
