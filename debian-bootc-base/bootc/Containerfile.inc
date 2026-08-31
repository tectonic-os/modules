# The label is what makes this a bootc image rather than a container that
# happens to carry bootc, and the CMD is what makes `podman run` boot it. The
# Debian base declares neither.
LABEL containers.bootc=1
CMD ["/sbin/init"]

# /var/cache and /var/log are build cache mounts on every generated layer, so
# the tool's own /var pass keeps them out of its walk and never sees what the
# *base image* left there — debconf's five .dat files, apt's lists, ldconfig's
# aux-cache, which `bootc container lint` then reports as /var content with no
# tmpfiles entry. A layer mounting neither is the only thing that can reach
# them, and this is the last place in the build where one is possible: every
# module layer below has both mounted, so nothing after this writes to either
# tree in the image.
RUN rm -rf /var/cache/* /var/log/*
