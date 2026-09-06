#!/bin/bash

# A bootc base ships an empty /var, so neither apt nor dpkg has a state
# directory to write to. dpkg's absence is the one that stops a build: apt
# reports `Could not open lock file /var/lib/dpkg/lock-frontend` before it
# resolves anything. A build also has no terminal to prompt at.
install_packages() {
	mkdir -p /var/lib/apt/lists/partial /var/cache/apt/archives/partial /var/log/apt
	mkdir -p /var/lib/dpkg/updates /var/lib/dpkg/info /var/lib/dpkg/triggers
	[ -f /var/lib/dpkg/status ] || : > /var/lib/dpkg/status
	DEBIAN_FRONTEND=noninteractive apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

# A third-party archive: its signing key, then the deb822 source that names
# it.
#
# `curl` is fetched rather than assumed: a `repo` file runs at the top of its
# module's layer, before anything that module installs, and whether some
# earlier layer happened to leave curl behind is a question about the sort
# order rather than about this module.
#
# Vendors serve the key either armored or binary and apt reads both, but it
# decides which by the file extension rather than by the content, so the
# extension is what this has to get right. `gpg --dearmor` would be the other
# answer and would put gnupg in every image that adds an archive.
#
# Idempotent by overwrite, which is what stands in for the `/etc/yum.repos.d`
# guard the emitter writes on Fedora and does not write here.
add_repo() {
	local id="$1" uri="$2" suite="$3" components="$4" key="$5"
	local at=/usr/share/keyrings ext=gpg

	command -v curl > /dev/null || install_packages curl ca-certificates
	install -d -m 0755 "$at"
	curl --retry 3 -fsSLo "$at/$id.key" "$key"
	# Read through grep rather than a command substitution: a binary key is
	# full of null bytes and bash drops them with a warning on every build.
	if head -c 64 "$at/$id.key" | grep -qa "BEGIN PGP PUBLIC KEY"; then
		ext=asc
	fi
	mv "$at/$id.key" "$at/$id.$ext"

	cat >"/etc/apt/sources.list.d/$id.sources" <<-EOF
		Types: deb
		URIs: $uri
		Suites: $suite
		Components: $components
		Signed-By: $at/$id.$ext
	EOF
}
