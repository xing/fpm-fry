# 0.3.1 / t.b.d

* [FEATURE] add experimental apt plugin
* [ENHANCEMENT] setting file_map parameter on source is now mostly superfluous
* [FEATURE] source learned a new :to option to change the target to change the path where the source resides

# 0.3.0 / 2016.10.16

* [CHANGE] also recognize urls starting with https://git. as git
* [CHANGE] also recognize urls with scheme git+... as git
* [ENHANCEMENT] tests can now run against a real docker host, improving test depth
* [ENHANCEMENT] removed OsDb. This file contained some hardcoded Os versions which was not future proof. It was a workaround to get started more quickly.
* [FIX] patched sources now fail when the underlying patch fails
* [CHANGE] Renamed "Source::Package" to "Source::Archive" which is more striking. The term "package" is also used for build results.
* [IMPROVEMENT] removed hardcoded init system list, try to guess the init system from the provided container
* [CHANGE] init plugin has a different syntax

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
