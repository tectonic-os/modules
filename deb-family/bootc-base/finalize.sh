# Module authors run this hook after package installs so the initramfs and
# relocated package state include every module. They leave `/opt` and `/var`
# tmpfiles rules to Tect's later finalizer.

# Debian maintainers install the kernel under `/boot`. Module authors copy it
# to the path that bootc requires under `/usr/lib/modules/<kver>`.
kver="$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n')"
# Maintainers test the empty case because `wc -l` counts an empty string as one.
if [ -z "$kver" ] || [ "$(printf '%s\n' "$kver" | wc -l)" != 1 ]; then
    echo "bootc wants exactly one kernel; /usr/lib/modules has: ${kver}" >&2
    exit 1
fi
[ -f "/usr/lib/modules/${kver}/vmlinuz" ] \
    || cp "/boot/vmlinuz-${kver}" "/usr/lib/modules/${kver}/vmlinuz"
depmod "$kver"
initramfs="/usr/lib/modules/${kver}/initramfs.img"
dracut --force --kver "$kver" "$initramfs"

# Image authors require the bootc setup paths and the cryptsetup executable
# because initramfs size and dracut module names do not prove their presence.
# They use a here-string because `grep -q` under `pipefail` would turn a
# successful piped match into a SIGPIPE failure.
listing="$(lsinitrd "$initramfs")"
for path in usr/lib/bootc/initramfs-setup \
    usr/lib/systemd/system/bootc-root-setup.service \
    usr/bin/systemd-cryptsetup; do
    if ! grep -q "[ /]${path}\$" <<< "$listing"; then
        echo "the initramfs carries no ${path}, so a machine from this image cannot boot" >&2
        exit 1
    fi
done

# Image authors require the TPM2 token plugin and its runtime-loaded tss2
# libraries because dracut cannot discover them through link dependencies.
# They match file names because each family uses a multiarch directory. Debian
# kernel maintainers build the TPM drivers into the kernel.
for name in libcryptsetup-token-systemd-tpm2.so libtss2-esys.so libtss2-rc.so \
    libtss2-mu.so libtss2-tcti-device.so; do
    if ! grep -q "/${name}[.0-9]*\$" <<< "$listing"; then
        echo "the initramfs carries no ${name}, so a TPM2 answer cannot unlock this image" >&2
        exit 1
    fi
done

# Operators keep image package state under `/usr` because bootc applies `/var`
# once during provisioning. Image authors leave `/var/cache/debconf` alone
# because the build backend mounts `/var/cache` outside the image layer.
mkdir -p /usr/lib/sysimage
for pair in \
    dpkg:/var/lib/dpkg \
    pam:/var/lib/pam \
    ucf:/var/lib/ucf \
    sgml-base:/var/lib/sgml-base \
    xml-core:/var/lib/xml-core \
    deb-systemd-helper-enabled:/var/lib/systemd/deb-systemd-helper-enabled \
    deb-systemd-user-helper-enabled:/var/lib/systemd/deb-systemd-user-helper-enabled; do
    from="${pair#*:}"
    to="/usr/lib/sysimage/${pair%%:*}"
    [ -L "$from" ] && continue
    # Module authors create each link before derived builds install its package.
    if [ -d "$from" ]; then mv "$from" "$to"; else mkdir -p "$to"; fi
    mkdir -p "$(dirname "$from")"
    ln -sfT "$to" "$from"
done
# Image authors cannot rely on boot-time tmpfiles during derived build layers.
# Maintainers count packages because dpkg reports a missing admindir as empty
# output with a successful exit.
packages="$(dpkg-query -W -f '.' | wc -c)"
if [ "$packages" -eq 0 ]; then
    echo "the relocated dpkg admindir answers for no packages at all" >&2
    exit 1
fi
echo "dpkg answers for ${packages} packages from /usr/lib/sysimage/dpkg"

: > /etc/machine-id
# Image authors remove package-created `/run` state for bootc lint. They keep
# the build backend's `secrets` and `.containerenv` mounts because `rm` cannot
# remove those mount points.
find /run -mindepth 1 -maxdepth 1 ! -name secrets ! -name .containerenv \
    -exec rm -rf {} +

# Image authors remove Ubuntu's base account so `login-access` owns account
# creation. They guard the removal because Debian has no `ubuntu` account.
if getent passwd ubuntu > /dev/null; then
    userdel ubuntu
fi
# Image authors remove the base D-Bus machine ID because its `L` tmpfiles rule
# will not replace an existing file at boot.
rm -f /var/lib/dbus/machine-id
rm -f /etc/ssh/ssh_host_*
# Image authors remove the container's placeholder fstab to avoid libmount's
# modification warning after bootc overlays `/etc`.
rm -f /etc/fstab

# Image authors remove package enablement so `login-access` controls SSH
# exposure. They also ship a disable preset because first-boot presetting would
# restore the package default.
rm -f /etc/systemd/system/multi-user.target.wants/ssh.service

# Image authors remove networkd's Ethernet match when they install
# NetworkManager to prevent two managers from configuring the same link.
if [ -x /usr/sbin/NetworkManager ]; then
    rm -f /usr/lib/systemd/network/89-ethernet.network
fi

# Image authors remove Docker's apt policy after package installation because
# `force-unsafe-io` risks package state during power loss. They leave hostname
# and resolver handling to the Containerfile and tmpfiles because the build
# backend bind-mounts those paths during `RUN`.
rm -f /etc/dpkg/dpkg.cfg.d/docker-apt-speedup
rm -f /etc/apt/apt.conf.d/docker-clean \
    /etc/apt/apt.conf.d/docker-gzip-indexes \
    /etc/apt/apt.conf.d/docker-no-languages \
    /etc/apt/apt.conf.d/docker-autoremove-suggests

# Image authors leave `/opt` to Tect's later finalizer because it would replace
# a symlink created here.
# shellcheck disable=SC2114
rm -rf /boot /home /root /srv /mnt /usr/local
mkdir -p /boot /sysroot /var/home /var/srv /var/mnt /var/usrlocal /var/roothome
chmod 0700 /var/roothome
ln -sT var/home /home
ln -sT var/roothome /root
ln -sT var/srv /srv
ln -sT var/mnt /mnt
ln -sT ../var/usrlocal /usr/local
ln -sT sysroot/ostree /ostree
