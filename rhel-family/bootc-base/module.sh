# The base shipped no systemd, so `build-environment` had nothing to stash, and
# this module's packages just installed one. Every later layer's scriptlets
# would reach it. The same stash, which `build-environment`'s finalize undoes.
# Scriptlets inside this module's own install ran against the real binary; the
# preset pass is what overrules them, and `validate-image` checks it did.
if [ ! -e /usr/bin/systemctl.bak ]; then
    mv /usr/bin/systemctl /usr/bin/systemctl.bak
    ln -s /usr/bin/true /usr/bin/systemctl
fi
