#!/bin/bash

# A bootc base ships an empty /var, so apt's state directories are not there for
# it to write to and `apt-get update` fails before it reads a single list. A
# build also has no terminal to prompt at.
install_packages() {
	mkdir -p /var/lib/apt/lists/partial /var/cache/apt/archives/partial /var/log/apt
	DEBIAN_FRONTEND=noninteractive apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}
