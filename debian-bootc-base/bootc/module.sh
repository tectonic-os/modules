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

src=/tmp/bootc
fetch_extract "$ASSET_BOOTC_URL" "$ASSET_BOOTC_SHA256" "$src"
cd "${src}/bootc-${ASSET_BOOTC_VERSION}" || exit

# The vendor tarball unpacks to ./vendor beside a `.cargo/vendor-config.toml`
# the source ships but does not apply, so cargo only stops reaching crates.io
# once the two are joined.
fetch_extract "$ASSET_BOOTC_VENDOR_URL" "$ASSET_BOOTC_VENDOR_SHA256" .
cat .cargo/vendor-config.toml >>.cargo/config.toml

# `install`, not `install-all`: the extra target is bootc's own integration
# test binary and the `ostree container` compatibility symlinks, and a product
# image wants neither.
make bin install DESTDIR=/
ldconfig
bootc --version

cd /
rm -rf "$src"
DEBIAN_FRONTEND=noninteractive apt-get purge -y "${BUILD_DEPS[@]}"
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge
