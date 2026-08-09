dnf5 -y copr enable ublue-os/packages
dnf5 -y copr disable ublue-os/packages
dnf5 -y install --enablerepo="copr:copr.fedorainfracloud.org:ublue-os:packages" \
    krunner-bazaar
