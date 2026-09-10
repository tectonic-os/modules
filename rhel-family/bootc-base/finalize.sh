# Runs after every module's installs: an initramfs built before the last
# package is a lie. The tool's own /opt and /var passes run after this hook.

# ---- the initramfs ----
# The EL kernel package already puts vmlinuz where bootc looks for it, so this
# only builds the initramfs beside it.
mapfile -t kvers < <(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
if [ "${#kvers[@]}" -ne 1 ]; then
    echo "bootc wants exactly one kernel; /usr/lib/modules has: ${kvers[*]}" >&2
    exit 1
fi
kver="${kvers[0]}"
[ -f "/usr/lib/modules/${kver}/vmlinuz" ] || {
    echo "the kernel package left no /usr/lib/modules/${kver}/vmlinuz" >&2
    exit 1
}
depmod "$kver"
initramfs="/usr/lib/modules/${kver}/initramfs.img"
dracut --force --kver "$kver" "$initramfs"

# `test -s` passes an initramfs with neither module in it: dracut logs `Module
# 'ostree' cannot be found` and still exits 0. Name the paths that mount the
# composefs deployment instead.
listing="$(lsinitrd "$initramfs")"
for path in usr/lib/ostree/ostree-prepare-root \
    usr/lib/bootc/initramfs-setup; do
    if ! grep -q "[ /]${path}\$" <<< "$listing"; then
        echo "the initramfs carries no ${path}, so it cannot mount a deployment" >&2
        exit 1
    fi
done

# ---- what a build must not bake in ----
: > /etc/machine-id
# Package scripts create directories under /run at unpack time and
# `bootc container lint` reports the lot as `nonempty-run-tmp`. `secrets` and
# `.containerenv` are the build backend's own mounts: `rm` answers `Device or
# resource busy` on them, so a plain `rm -rf /run/*` fails the build.
find /run -mindepth 1 -maxdepth 1 ! -name secrets ! -name .containerenv \
    -exec rm -rf {} +
rm -f /etc/ssh/ssh_host_*
# bootc overlays /etc, and libmount warns "fstab has been modified" at boot
# over a placeholder no machine wants.
rm -f /etc/fstab

# ---- the ostree-shaped root ----
# What `centos-bootc:stream10` is shaped like, measured 2026-09-11: /home,
# /root, /srv and /mnt are symlinks into /var, /ostree points into /sysroot,
# and /usr/local stays a real directory, which is where EL differs from the deb
# base. /opt is not here: the tool's own finalize relocates it and restores the
# base's directory afterwards.
# /boot is emptied rather than kept: the kernel package leaves its vmlinuz,
# config, System.map and a second initramfs there, and `bootc install`
# populates the real one. `centos-bootc:stream10` ships an empty /boot and
# `bootc container lint` warns about anything else.
# shellcheck disable=SC2114 # replacing the system directories is the point
rm -rf /home /root /srv /mnt /boot
mkdir -p /boot /sysroot /var/home /var/srv /var/mnt /var/roothome
chmod 0700 /var/roothome
ln -sT var/home /home
ln -sT var/roothome /root
ln -sT var/srv /srv
ln -sT var/mnt /mnt
ln -sT sysroot/ostree /ostree
