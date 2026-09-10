source /ctx/lib/family.sh

# Debian ships `firefox-esr` and no `firefox`; Ubuntu's `firefox` is a snap
# transitional. Mozilla's own archive is the only apt route to a current
# Firefox on either, and it serves one suite for every distribution, so
# nothing here reads /etc/os-release.
add_repo "mozilla" \
    "https://packages.mozilla.org/apt" "mozilla" "main" \
    "https://packages.mozilla.org/apt/repo-signing-key.gpg"

# Ubuntu's transitional package carries the same upstream version numbering as
# Mozilla's, so without this the winner is a dpkg version compare between two
# spellings of one release rather than a decision. Mozilla's own instructions
# pin it and this is that pin.
cat > /etc/apt/preferences.d/mozilla << 'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
