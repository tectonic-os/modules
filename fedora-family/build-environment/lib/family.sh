#!/bin/bash

# A package scriptlet may not enable a unit; the preset pass decides that. So
# `systemctl` is a stub from the moment it exists, whichever install brought it
# or upgraded it, and `build-environment`'s finalize puts the real one back.
stash_systemctl() {
    [ -e /usr/bin/systemctl ] || return 0
    [ "$(readlink /usr/bin/systemctl)" = /usr/bin/true ] && return 0
    mv -f /usr/bin/systemctl /usr/bin/systemctl.bak
    ln -s /usr/bin/true /usr/bin/systemctl
}

# `dnf` is dnf5 on Fedora and dnf4 on CentOS Stream 10, and both take these arguments.
# COPR and `addrepo` below are dnf5's, so Fedora's alone.
install_packages() {
    local args=()
    if [ -n "${TECT_ENABLE_REPO:-}" ]; then
        args+=(--enablerepo="$TECT_ENABLE_REPO")
    fi
    dnf install -y "${args[@]}" "$@"
    stash_systemctl
}

install_groups() {
    local args=()
    if [ -n "${TECT_ENABLE_REPO:-}" ]; then
        args+=(--enablerepo="$TECT_ENABLE_REPO")
    fi
    dnf group install -y "${args[@]}" "$@"
    stash_systemctl
}

enable_copr() {
    dnf5 -y copr enable "$1"
    dnf5 -y copr disable "$1"
}

# A third-party archive added and then turned off, so a module that wants one
# package out of it does not hand the whole archive to every later resolve.
# `enablerepo=` on a `packages` batch is what turns it back on, through the
# `TECT_ENABLE_REPO` that `install_packages` above reads.
#
# The `.repo` file the vendor publishes is the interface here, which is why
# this takes a URL where the deb-family `add_repo` takes the four fields apt
# wants: the two package managers name an archive differently and pretending
# otherwise would cost a translation layer neither of them asked for.
add_disabled_repo() {
    dnf5 config-manager addrepo --from-repofile="$1"
    dnf5 config-manager setopt "${REPO_ID:?add_disabled_repo needs REPO_ID set}.enabled=0"
}
