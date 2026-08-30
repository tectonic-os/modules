source /ctx/lib/fetch-helpers.sh

# Both halves move, or the install is worse than none: a binary without its own
# assets scaffolds from whatever stale copy the host has, with no diagnostic.
# /usr/share/tectonic/assets is the second entry of INSTALLED, so nothing here
# or on the booted machine has to set TECT_ASSETS.
fetch_extract "$ASSET_TECT_URL" "$ASSET_TECT_SHA256" /tmp/tect
install -D -m755 /tmp/tect/tect /usr/bin/tect

# Swapped, never copied over: `cp -a src dst` copies *into* an existing dst,
# which would leave `assets/assets`, and a copy-over would keep an asset a
# later release dropped. This is the same rule the installer follows.
mkdir -p /usr/share/tectonic
rm -rf /usr/share/tectonic/assets
mv /tmp/tect/assets /usr/share/tectonic/assets
rm -rf /tmp/tect
