# A package scriptlet may not enable a unit; the preset pass decides that. A
# base carrying no systemd has nothing to stash and installs one later in the
# build, which is `rockylinux:10` and every container image of that shape.
if [ -e /usr/bin/systemctl ] && [ ! -e /usr/bin/systemctl.bak ]; then
    mv /usr/bin/systemctl /usr/bin/systemctl.bak
    ln -s /usr/bin/true /usr/bin/systemctl
fi

# CentOS Stream 10 ships dnf4 and no dnf5, and COPR is Fedora's.
if command -v dnf5 > /dev/null; then
    dnf5 install -y dnf5-plugins
fi
