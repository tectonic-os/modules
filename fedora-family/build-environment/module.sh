mv /usr/bin/systemctl /usr/bin/systemctl.bak
ln -s /usr/bin/true /usr/bin/systemctl

# CentOS Stream 10 ships dnf4 and no dnf5, and COPR is Fedora's.
if command -v dnf5 > /dev/null; then
    dnf5 install -y dnf5-plugins
fi
