# Runs after every module's installs, which is the whole point: an initramfs
# built before the last package is a lie, and state moved out of /var before
# the last install leaves the rest of it behind. The tool's own /opt and /var
# passes run after this hook, so nothing here writes a tmpfiles rule for a
# directory it leaves in /var — that pass records them.

# ---- the initramfs ----
# bootc looks for the kernel at /usr/lib/modules/<kver>/vmlinuz, which is not
# where the Debian package puts it.
kver="$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n')"
# `wc -l` counts 1 for the empty string, so no kernel at all would pass a count
# check and fail later on `cp /boot/vmlinuz-` instead — which is the confusing
# failure this guard exists to replace.
if [ -z "$kver" ] || [ "$(printf '%s\n' "$kver" | wc -l)" != 1 ]; then
	echo "bootc wants exactly one kernel; /usr/lib/modules has: ${kver}" >&2
	exit 1
fi
[ -f "/usr/lib/modules/${kver}/vmlinuz" ] ||
	cp "/boot/vmlinuz-${kver}" "/usr/lib/modules/${kver}/vmlinuz"
depmod "$kver"
initramfs="/usr/lib/modules/${kver}/initramfs.img"
dracut --force --kver "$kver" "$initramfs"

# `test -s` passes an initramfs with no bootc in it at all, which is what the
# base deleted on 2026-08-30 shipped. Name the two paths that mount the
# composefs deployment instead.
# A here-string and not a pipe: `grep -q` closes the pipe on its first match,
# the writer takes SIGPIPE, and `pipefail` then reports the whole pipeline as
# failed — so a piped form of this check fails loudest when it passes.
listing="$(lsinitrd "$initramfs")"
for path in usr/lib/bootc/initramfs-setup \
	usr/lib/systemd/system/bootc-root-setup.service; do
	if ! grep -q "[ /]${path}\$" <<<"$listing"; then
		echo "the initramfs carries no ${path}, so it cannot mount a deployment" >&2
		exit 1
	fi
done

# ---- package state out of /var ----
# /var is applied once at provisioning and never touched by `bootc upgrade`, so
# state that describes the *image* has to live under /usr or a long-lived
# machine's `dpkg -l` becomes fiction. Each of these has broken a build:
# `sgml-base` and `xml-core` fail their postinst triggers on a directory the
# package ships and /var no longer has, and `ucf` and the two
# deb-systemd-helper stores are the same class.
#
# `debconf` belongs to that class and is deliberately *not* here. Its database
# is `/var/cache/debconf`, and `/var/cache` is a build cache mount on every
# layer: moving it writes the replacement symlink onto the cache rather than
# into the image, where it outlives this build and points at nothing in the
# next one — measured, as a `DbDriver "config": could not open` on a later
# build that shared the cache. Nothing under `/var/cache` reaches the image
# either way, so there is nothing to relocate.
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
	# A directory no package has created yet still gets its link, so the first
	# install in a derived build writes to the relocated copy.
	if [ -d "$from" ]; then mv "$from" "$to"; else mkdir -p "$to"; fi
	mkdir -p "$(dirname "$from")"
	ln -sfT "$to" "$from"
done
# The link is made here as well as in tmpfiles.d because every RUN layer of a
# derived build executes before systemd-tmpfiles ever does.
#
# And this is the check, not the log line it started as: an admindir `dpkg` can
# no longer find is not an error, it is an empty database reported at **exit
# 0**, so the count is the only thing that says the relocation worked.
packages="$(dpkg-query -W -f '.' | wc -c)"
if [ "$packages" -eq 0 ]; then
	echo "the relocated dpkg admindir answers for no packages at all" >&2
	exit 1
fi
echo "dpkg answers for ${packages} packages from /usr/lib/sysimage/dpkg"

# ---- what a build must not bake in ----
: >/etc/machine-id
# Debian's `dbus.conf` declares /var/lib/dbus/machine-id, so the tool's /var
# pass skips it *and* leaves the file on disk — and it declares it with `L`
# rather than `L+`, so tmpfiles will not replace it at boot either. Left alone,
# every machine installed from this base shares one D-Bus machine ID that does
# not match its systemd one.
rm -f /var/lib/dbus/machine-id
rm -f /etc/ssh/ssh_host_*
# bootc overlays /etc, and libmount warns "fstab has been modified" at boot
# over a placeholder the container image ships and no machine wants.
rm -f /etc/fstab

# ---- the ostree-shaped root ----
# /opt is not here: the tool's own finalize relocates it and restores the
# base's directory afterwards, so a symlink written now would be thrown away.
# shellcheck disable=SC2114 # replacing the system directories is the point
rm -rf /boot /home /root /srv /mnt /usr/local
mkdir -p /boot /sysroot /var/home /var/srv /var/mnt /var/usrlocal /var/roothome
chmod 0700 /var/roothome
ln -sT var/home /home
ln -sT var/roothome /root
ln -sT var/srv /srv
ln -sT var/mnt /mnt
ln -sT ../var/usrlocal /usr/local
ln -sT sysroot/ostree /ostree
