# `/etc/bashrc` on Fedora is `/etc/bash.bashrc` here, and the file carries no
# `umask` at all on either base -- measured on debian:forky and ubuntu:26.04,
# where neither it nor `/etc/profile` sets one. So the substitution is kept for
# a base that grows one and the append is what actually fires today.
sed -i 's/\bumask 0\?22\b/umask 027/g' /etc/bash.bashrc
grep -qE '^[[:space:]]*umask[[:space:]]' /etc/bash.bashrc || printf 'umask 027\n' >> /etc/bash.bashrc
