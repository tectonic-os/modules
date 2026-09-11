# The archives' own mirrors crawl from a CI runner, so the build fetches through
# Azure's, which GitHub's runners use, and retries a stalled connection.
# `finalize.sh` puts back the base's sources, so the image ships them.
mkdir -p /etc/apt/tect-build
for sources in /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/debian.sources; do
    [ -f "$sources" ] || continue
    cp -p "$sources" /etc/apt/tect-build/
    sed -i -e 's|http://archive.ubuntu.com/|http://azure.archive.ubuntu.com/|' \
        -e 's|http://deb.debian.org/|http://debian-archive.trafficmanager.net/|' "$sources"
done
printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\n' > /etc/apt/apt.conf.d/80-tect-build

# `ubuntu:*` ships `/etc/dpkg/dpkg.cfg.d/excludes`, which `path-exclude`s every
# man page, every `/usr/share/doc` file but `copyright` and `changelog`, and the
# locale catalogues. A `path-exclude` applies at *unpack* time and is inherited,
# permanent and silent: deleting the file gives documentation back to packages
# installed after it and restores nothing already on disk. So the reinstall is
# the other half, and every published Ubuntu bootc base skips it. It costs 27s
# and 39 MB.
#
# Here rather than in `deb-family/bootc-base` because this is the module every deb
# build's closure puts first — it has to run before the first install of any
# module, and `provides "build-environment"` is what guarantees that. `debian:*`
# ships no such file and the guard is what makes this one module for both.
if [ -f /etc/dpkg/dpkg.cfg.d/excludes ]; then
    rm -f /etc/dpkg/dpkg.cfg.d/excludes
    # The state directories and the update are `install_packages`, which cannot
    # be called here: it has no `--reinstall`. A base ships no package lists, so
    # without the update apt can download nothing and reinstalls nothing.
    mkdir -p /var/lib/apt/lists/partial /var/cache/apt/archives/partial /var/log/apt
    DEBIAN_FRONTEND=noninteractive apt-get update
    # shellcheck disable=SC2046 # one package name per line is the point
    DEBIAN_FRONTEND=noninteractive apt-get install --reinstall -y \
        $(dpkg-query -W -f '${binary:Package}\n')
    # The repair fails silently. `apt-get install --reinstall` prints
    # `Reinstallation of <pkg> is not possible, it cannot be downloaded` per
    # package and exits 0, so an image with every path-exclude still in place
    # builds green. Measured 2026-09-08 on `ubuntu:26.04`: man1 0 -> 0 without
    # the update above, 0 -> 459 with it.
    compgen -G '/usr/share/man/man1/*' > /dev/null || {
        echo "build-environment: the path-exclude repair restored no man pages" >&2
        exit 1
    }
fi

if [ -e /usr/sbin/policy-rc.d ]; then
    mv /usr/sbin/policy-rc.d /usr/sbin/policy-rc.d.bak
fi
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d
