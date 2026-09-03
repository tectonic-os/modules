# The label is what makes this a bootc image rather than a container that
# happens to carry bootc, and the CMD is what makes `podman run` boot it. The
# Debian base declares neither. Note that a fragment is emitted with no flavour
# guard, so both would apply even to a build where a flavour-gated version of
# this module's layer was skipped; this module is not flavour-gated.
LABEL containers.bootc=1
CMD ["/sbin/init"]

# /var/cache and /var/log are build cache mounts on every *module* layer, so
# the tool's own /var pass keeps them out of its walk and never sees what the
# base image left there — debconf's five .dat files, apt's lists, ldconfig's
# aux-cache, which `bootc container lint` then reports as /var content with no
# tmpfiles entry. A layer mounting neither is the only thing that can reach
# them. This is the last place a *module* can do it; the four layers the
# skeleton adds below the modules mount neither either, and one of them runs
# `systemd-analyze verify`, which shells out to man — so if /var/cache/man ever
# turns up in a built image, that is where it came from and not from here.
RUN rm -rf /var/cache/* /var/log/*

# `/etc/hostname` is `debuerreotype` — the name of the tool that builds the
# Debian container image — and it outranks the `DEFAULT_HOSTNAME` that `tect
# os-release` writes from the image's own name, so every machine installed from
# this base came up under it. Measured 2026-09-01 on the first boot, and again
# in the built image: the earlier note that the file carried the *build
# container's id* was a reading through podman's runtime mount, not image
# content.
#
# A `COPY` and not a line in `finalize.sh`, because this is one of the three
# paths the build backend bind-mounts into every `RUN`: `rm` inside a layer
# answers `Device or resource busy` and the image keeps the base's copy
# regardless. A `COPY` writes no container and so sees no mount.
#
# The heredoc leaves one newline, which is what systemd wants: it skips empty
# and commented lines, finds no hostname, and falls back to `DEFAULT_HOSTNAME`.
COPY <<EOF /etc/hostname
EOF
