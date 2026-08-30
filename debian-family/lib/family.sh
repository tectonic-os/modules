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
