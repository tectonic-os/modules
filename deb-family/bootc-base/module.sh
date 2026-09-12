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

# **bootc and bootupd are compiled here from the pins in `module.kdl`.** That
# is the default and `build-tools.sh` beside this file is all of it: upstream's
# own released source, held to a hash, built in this layer, purged of its
# toolchain before the layer ends. Nothing is fetched that was not compiled
# where anyone can read how.
#
# `prebuilt-tools #true` on the module trades that for a tarball built from
# these same pins, which is 212s of compile on a 32-thread host and 18m13s on
# a 4-vCPU runner. An image opts in in its own image file, so the choice is
# visible in the repository that made it. Nothing publishes that tarball yet,
# so opting in today compiles and says so.
#
# **Opting in cannot fail a build and cannot install an unverified binary.**
# A tarball that is absent — no release yet, a pin bumped before one was
# published, a fork with none of its own — and one that is not the pinned
# bytes both land back on the compile, loudly.
vendor="$(. /etc/os-release && echo "$ID")"
tools=/tmp/bootc-tools.tar.zst
from_source=yes
if [ "${OPT_PREBUILT_TOOLS:-0}" = 1 ]; then
    pin="ASSET_BOOTC_TOOLS_${vendor^^}"
    url="${pin}_URL"
    sha="${pin}_SHA256"
    if curl --retry 3 -fsSLo "$tools" "${!url}" \
        && echo "${!sha}  ${tools}" | sha256sum --status -c -; then
        tar --use-compress-program=zstd -xf "$tools" -C /
        from_source=no
    else
        echo "bootc-base: prebuilt-tools is set and no tarball matching" \
            "${!sha} is at ${!url}; compiling from the pins instead" >&2
    fi
    rm -f "$tools"
fi
[ "$from_source" = no ] || bash "${MODDIR}/build-tools.sh"
ldconfig
bootc --version
bootupctl --version

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

# Upstream's own stub, which `make install-grub-static` put beside the
# configs.d this module pruned, so it is read out of the installed tree rather
# than out of a source tree the tarball path never unpacks.
# It resolves /boot by the UUID `bootupctl backend install --write-uuid` leaves
# beside it, falling back to the `boot` label, and reads the real menu from
# `grub2/grub.cfg` on a separate /boot partition or `boot/grub2/grub.cfg` when
# /boot is a directory on the root filesystem. Both arms use only commands a
# deb signed GRUB carries: it has `search`, `source` and `configfile`, and no
# `blscfg`, which is why nothing here asks for one.
install -D -m 0644 /usr/lib/bootupd/grub2-static/grub-static-efi.cfg \
    "${grub_dir}/${vendor}/grub.cfg"

# Turns the tree above into `/usr/lib/bootupd/updates`, which is half of what
# `bootc` probes for when it decides whether GRUB is installable at all — the
# other half being `bootupctl` on PATH.
bootupctl backend generate-update-metadata /
