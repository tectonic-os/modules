source /ctx/lib/fetch-helpers.sh

# The one thing that decides whether this base is buildable at all, checked
# before a toolchain is installed rather than after a five-minute compile:
# every `bootc` carrying `--composefs-backend` — the flag that makes an install
# reach a bootloader without `bootupd`, which Debian does not package — needs
# libostree 2025.3 or newer. Debian has that from forky on; trixie ships
# 2025.2 and cannot host this module at all.
# Asked of dpkg rather than pkg-config, which is itself one of the build
# dependencies this check exists to avoid installing.
NEEDS_OSTREE=2025.3
HAS_OSTREE="$(dpkg-query -W -f '${Version}' libostree-1-1)"
if ! dpkg --compare-versions "$HAS_OSTREE" ge "$NEEDS_OSTREE"; then
	echo "this base carries libostree ${HAS_OSTREE}, and bootc" \
		"${ASSET_BOOTC_VERSION} needs >= ${NEEDS_OSTREE}" >&2
	exit 1
fi

# Purged again at the end of this layer, which is why the whole build lives in
# one module: nothing here reaches the image. `autoremove` is safe beside other
# modules because every one of them installs through `install_packages`, which
# leaves its packages marked manual — autoremove takes only what nothing
# manually installed still depends on.
BUILD_DEPS=(
	build-essential rustc cargo
	libostree-dev libzstd-dev libssl-dev pkgconf go-md2man
)
install_packages "${BUILD_DEPS[@]}"

# Two pins for one release, and nothing else compares them: a bump that moved
# only one would leave cargo resolving against a vendor tree for a different
# version, which it would answer by reaching crates.io rather than by failing.
if [ "$ASSET_BOOTC_VERSION" != "$ASSET_BOOTC_VENDOR_VERSION" ]; then
	echo "bootc is pinned at ${ASSET_BOOTC_VERSION} and its vendor tarball at" \
		"${ASSET_BOOTC_VENDOR_VERSION}; both pins move together" >&2
	exit 1
fi

src=/tmp/bootc
fetch_extract "$ASSET_BOOTC_URL" "$ASSET_BOOTC_SHA256" "$src"
cd "${src}/bootc-${ASSET_BOOTC_VERSION}" || exit

# The vendor tarball unpacks to ./vendor beside a `.cargo/vendor-config.toml`
# the source ships but does not apply, so cargo only stops reaching crates.io
# once the two are joined.
fetch_extract "$ASSET_BOOTC_VENDOR_URL" "$ASSET_BOOTC_VENDOR_SHA256" .
cat .cargo/vendor-config.toml >>.cargo/config.toml

# The vendored sources are an arrangement, not a guarantee, so say so: offline
# makes a missing or mismatched vendor tree a build failure rather than a
# silent fetch, and `--locked` refuses a Cargo.lock that would have to move.
export CARGO_NET_OFFLINE=true
export CARGO_BUILD_LOCKED=true

# Upstream's release profile sets `debug = true` because it expects an RPM to
# split the debuginfo back out, and nothing here does: unstripped, `bootc`
# alone lands at 326 MB of a 1.15 GB image, and being unpackaged it is invisible
# to the very scanners this base exists to answer honestly.
export CARGO_PROFILE_RELEASE_DEBUG=false
export CARGO_PROFILE_RELEASE_STRIP=true

# `install`, not `install-all`: the extra target is bootc's own integration
# test binary and the `ostree container` compatibility symlinks, and a product
# image wants neither.
make bin install DESTDIR=/
ldconfig
bootc --version

cd /
rm -rf "$src"

# ---- bootupd, and the signed chain it installs ----
# Same two pins, same reason, and the same check that they move together.
if [ "$ASSET_BOOTUPD_VERSION" != "$ASSET_BOOTUPD_VENDOR_VERSION" ]; then
	echo "bootupd is pinned at ${ASSET_BOOTUPD_VERSION} and its vendor tarball" \
		"at ${ASSET_BOOTUPD_VENDOR_VERSION}; both pins move together" >&2
	exit 1
fi

src=/tmp/bootupd
fetch_extract "$ASSET_BOOTUPD_URL" "$ASSET_BOOTUPD_SHA256" "$src"
cd "${src}/bootupd-${ASSET_BOOTUPD_VERSION}" || exit
fetch_extract "$ASSET_BOOTUPD_VENDOR_URL" "$ASSET_BOOTUPD_VENDOR_SHA256" .

# bootc's vendor tarball carries the `.cargo` fragment that redirects crates.io
# at it and bootupd's carries only the tree, so the redirect is written here.
# Same effect, and the same failure if it is missing: cargo reaches the network.
mkdir -p .cargo
cat >>.cargo/config.toml <<'CARGO'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
CARGO

# `install-grub-static` is not optional however much it reads like it: the EFI
# component installs the static configs on every GRUB install, not only when
# `--with-static-configs` is asked for, and without them the install fails
# after the disk is partitioned with `Installing static GRUB configs: No such
# file or directory`. `install-systemd-unit` is left out — that unit updates
# the bootloader on a booted machine and nothing here enables it.
make all install install-grub-static DESTDIR=/ PREFIX=/usr LIBEXECDIR=/usr/libexec
bootupctl --version

# The one fragment of the static config that is Fedora's rather than generic:
# a bare `blscfg`, the command that turns /boot/loader/entries into a menu.
# **No deb GRUB has it** — `blsuki.mod` ships in `grub-efi-amd64-bin` and is not
# built into the signed image, which refuses to load modules under Secure Boot
# at all. Left in place it is an error at every boot, so it goes; what replaces
# it is the plan's open half.
rm -f /usr/lib/bootupd/grub2-static/configs.d/10_blscfg.cfg

# bootupd hardcodes Fedora's spelling of two GRUB binaries, and the deb
# families ship the same programs under the unsuffixed name. `grub2-editenv`
# is reached on every install — it creates the `grubenv` beside the static
# config — and `grub2-install` only on the BIOS component, which has no
# payload here and is skipped. The symlink is the whole difference.
ln -sf grub-editenv /usr/bin/grub2-editenv

# The payload bootupd installs from, in the `usr/lib/efi/<name>/<version>/EFI`
# layout it reads without a package database — the alternative layout is
# `usr/lib/ostree-boot`, which bootupd versions by shelling out to `rpm -qf`.
# The component *names* are bootupd's, not ours: it filters the payload by
# bootloader and drops every component named after a different one, so the
# signed GRUB has to be called `grub2` however Debian spells the package.
# Versions are dpkg's, so what lands on an ESP can be traced back to the
# package it came from.
#
# Both families keep the pair in two trees with a `.signed` suffix and no
# vendor directory; the vendor is the os-release ID, which is what their
# `grubx64.efi` embeds as its prefix and where its shim looks for a second
# stage. Ubuntu's MokManager is unsigned, so it is left behind rather than
# staged — an unsigned one cannot load under Secure Boot anyway.
vendor="$(. /etc/os-release && echo "$ID")"
shim_dir="/usr/lib/efi/shim/$(dpkg-query -W -f '${Version}' shim-signed)/EFI"
grub_dir="/usr/lib/efi/grub2/$(dpkg-query -W -f '${Version}' grub-efi-amd64-signed)/EFI"

install -D -m 0644 /usr/lib/shim/shimx64.efi.signed "${shim_dir}/${vendor}/shimx64.efi"
install -D -m 0644 /usr/lib/shim/shimx64.efi.signed "${shim_dir}/BOOT/BOOTX64.EFI"
# Debian signs the fallback and Ubuntu does not ship a signed one at all —
# only `fbx64.efi`, the same split as its MokManager. An unsigned fallback
# cannot load under Secure Boot, so Ubuntu goes without: the fallback exists to
# write an NVRAM entry from `BOOTX64.CSV`, and the removable path boots without
# one, which is the path `--generic-image` leaves as the only one anyway.
if [ -f /usr/lib/shim/fbx64.efi.signed ]; then
	install -D -m 0644 /usr/lib/shim/fbx64.efi.signed "${shim_dir}/BOOT/fbx64.efi"
fi
if [ -f /usr/lib/shim/mmx64.efi.signed ]; then
	install -D -m 0644 /usr/lib/shim/mmx64.efi.signed "${shim_dir}/${vendor}/mmx64.efi"
fi
install -D -m 0644 /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed \
	"${grub_dir}/${vendor}/grubx64.efi"

# The removable path has to boot on its own, and `--generic-image` is what
# makes that the only path: bootc passes it to skip the `efibootmgr` call, so
# nothing writes an NVRAM entry naming the vendor directory. Measured as a
# reset loop — firmware starts `EFI/BOOT/BOOTX64.EFI`, shim looks for its
# second stage *in its own directory*, finds none, launches the fallback, and
# the fallback resets having nothing to create an entry from. The second stage
# beside shim is what fixes it; `BOOTX64.CSV` is what the fallback wants for
# the firmware that does keep NVRAM entries, and both cost a few hundred KB.
install -D -m 0644 /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed \
	"${shim_dir}/BOOT/grubx64.efi"
install -D -m 0644 /usr/lib/shim/BOOTX64.CSV "${shim_dir}/${vendor}/BOOTX64.CSV"

# Upstream's own stub, taken from the pinned source rather than written here.
# It resolves /boot by the UUID `bootupctl backend install --write-uuid` leaves
# beside it, falling back to the `boot` label, and reads the real menu from
# `grub2/grub.cfg` on a separate /boot partition or `boot/grub2/grub.cfg` when
# /boot is a directory on the root filesystem. Both arms use only commands a
# deb signed GRUB carries: it has `search`, `source` and `configfile`, and no
# `blscfg`, which is why nothing here asks for one.
install -D -m 0644 src/grub2/grub-static-efi.cfg "${grub_dir}/${vendor}/grub.cfg"

# Turns the tree above into `/usr/lib/bootupd/updates`, which is half of what
# `bootc` probes for when it decides whether GRUB is installable at all — the
# other half being `bootupctl` on PATH.
bootupctl backend generate-update-metadata /

cd /
rm -rf "$src"

DEBIAN_FRONTEND=noninteractive apt-get purge -y "${BUILD_DEPS[@]}"
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge
