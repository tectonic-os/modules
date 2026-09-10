# The label is what makes this a bootc image rather than a container carrying
# bootc, and the CMD is what makes `podman run` boot it. The Rocky base
# declares neither.
LABEL containers.bootc=1
CMD ["/sbin/init"]

# /var/cache and /var/log are build cache mounts on every module layer, so the
# tool's own /var pass never sees what the base image left there — dnf's
# metadata and ldconfig's aux-cache, which `bootc container lint` then reports
# as /var content with no tmpfiles entry. A layer mounting neither is the only
# thing that can reach them.
RUN rm -rf /var/cache/* /var/log/*
