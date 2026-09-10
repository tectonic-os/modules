# A package scriptlet may not enable a unit; the preset pass decides that. A
# base carrying no systemd has nothing to stash and installs one later in the
# build, which is `rockylinux:10` and every container image of that shape.
if [ -e /usr/bin/systemctl ] && [ ! -e /usr/bin/systemctl.bak ]; then
    mv /usr/bin/systemctl /usr/bin/systemctl.bak
    ln -s /usr/bin/true /usr/bin/systemctl
fi

# A plain container image installs no documentation: `rockylinux:10` sets
# `tsflags=nodocs`, which is the rpm twin of Ubuntu's dpkg excludes. A machine
# wants its man pages, since `systemd-analyze verify` renders every
# `Documentation=man:` a unit declares. Measured 2026-09-11: no bootc rpm base
# carries the line, so this reaches the container images alone.
sed -i '/^tsflags=nodocs$/d' /etc/dnf/dnf.conf

# CentOS Stream 10 ships dnf4 and no dnf5, and COPR is Fedora's.
if command -v dnf5 > /dev/null; then
    dnf5 install -y dnf5-plugins
fi
