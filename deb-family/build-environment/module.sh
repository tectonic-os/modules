# `ubuntu:*` ships `/etc/dpkg/dpkg.cfg.d/excludes`, which `path-exclude`s every
# man page, every `/usr/share/doc` file but `copyright` and `changelog`, and the
# locale catalogues. A `path-exclude` applies at *unpack* time and is inherited,
# permanent and silent: deleting the file gives documentation back to packages
# installed after it and restores nothing already on disk. So the reinstall is
# the other half, and every published Ubuntu bootc base skips it. Measured
# 2026-09-03 on `ubuntu:26.04`: `man1` 0 -> 459 pages, 27s, 39 MB.
#
# Here rather than in `deb-family/bootc-base` because this is the module every deb
# build's closure puts first — it has to run before the first install of any
# module, and `provides "build-environment"` is what guarantees that. `debian:*`
# ships no such file and the guard is what makes this one module for both.
if [ -f /etc/dpkg/dpkg.cfg.d/excludes ]; then
	rm -f /etc/dpkg/dpkg.cfg.d/excludes
	# shellcheck disable=SC2046 # one package name per line is the point
	DEBIAN_FRONTEND=noninteractive apt-get install --reinstall -y \
		$(dpkg-query -W -f '${binary:Package}\n')
fi

if [ -e /usr/sbin/policy-rc.d ]; then
	mv /usr/sbin/policy-rc.d /usr/sbin/policy-rc.d.bak
fi
printf '#!/bin/sh\nexit 101\n' >/usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d
