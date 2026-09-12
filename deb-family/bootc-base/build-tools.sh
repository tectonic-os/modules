#!/usr/bin/env bash
# bootc and bootupd, compiled from this module's pins into `$DESTDIR`.
#
# `module.sh` runs it whenever it is not taking a published tarball, which
# today is always. `DESTDIR` is what lets one file serve a publisher too: a
# staging tree tarred up is the same bytes this installs. It leaves the image
# no build dependency — everything it installs is purged at the end, which is
# why the whole compile is one layer.
#
# Only what the pins decide goes in here. The shim and GRUB payload bootupd
# installs from is versioned by dpkg and belongs to the base rather than to a
# pin, so it stays in `module.sh` with `generate-update-metadata` after it.
set -euxo pipefail

source /ctx/lib/family.sh
source /ctx/lib/fetch-helpers.sh

# `/` with no trailing slash, so every path below is `${DEST}/usr/...` whether
# this is staging a tarball or writing the image itself.
DEST="${DESTDIR:-/}"
DEST="${DEST%/}"

# Purged again at the end of this script, which is why the whole build lives in
# one module layer. `autoremove` is safe beside other modules because every one
# of them installs through `install_packages`, which leaves its packages marked
# manual — autoremove takes only what nothing manually installed still depends
# on.
#
# **It does not get everything, and the old claim that nothing here reaches the
# image is false by 41.6 MB.** Measured 2026-09-12 by diffing this against an
# image built from a prebuilt tarball: 261 packages against 251, the difference
# being binutils with its six libraries, `libgprofng0`, `libjansson4` and
# `libglib2.0-data`. In the finished image both heads are marked *manual* with
# nothing installed depending on them, which is why `autoremove` leaves them —
# **and what marks them manual is not known**: the same install, purge and
# autoremove on a bare base removes them correctly. `NEXT-46` stage 6 holds it.
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
cat .cargo/vendor-config.toml >> .cargo/config.toml

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
make bin install DESTDIR="${DEST:-/}"
"${DEST}/usr/bin/bootc" --version

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
cat >> .cargo/config.toml << 'CARGO'
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
make all install install-grub-static DESTDIR="${DEST:-/}" PREFIX=/usr LIBEXECDIR=/usr/libexec
"${DEST}/usr/bin/bootupctl" --version

# The one fragment of the static config that is Fedora's rather than generic:
# a bare `blscfg`, the command that turns /boot/loader/entries into a menu.
# **No deb GRUB has it** — `blsuki.mod` ships in `grub-efi-amd64-bin` and is not
# built into the signed image, which refuses to load modules under Secure Boot
# at all. Left in place it is an error at every boot, so it goes; what replaces
# it is the plan's open half.
rm -f "${DEST}/usr/lib/bootupd/grub2-static/configs.d/10_blscfg.cfg"

# bootupd hardcodes Fedora's spelling of two GRUB binaries, and the deb
# families ship the same programs under the unsuffixed name. `grub2-editenv`
# is reached on every install — it creates the `grubenv` beside the static
# config — and `grub2-install` only on the BIOS component, which has no
# payload here and is skipped. The symlink is the whole difference, and it
# dangles in a staging tree until the tarball is unpacked over the image.
ln -sf grub-editenv "${DEST}/usr/bin/grub2-editenv"

cd /
rm -rf "$src"

DEBIAN_FRONTEND=noninteractive apt-get purge -y "${BUILD_DEPS[@]}"
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge
