# The same line, and it needs two edits rather than one. Debian ships it as
# `# auth       required   pam_wheel.so` -- no `use_uid`, and a different run of
# spaces -- so the Fedora `sed` matches nothing here. And `wheel` is a Fedora
# group: `getent group wheel` is empty on debian:forky and ubuntu:26.04, where
# the administrative group is `sudo`. Uncommenting the line as it stands would
# hold `su` to a group nobody can be in, which is a lockout rather than a
# restriction.
sed -i 's/^#[[:space:]]*\(auth[[:space:]]\+required[[:space:]]\+pam_wheel\.so\)$/\1 use_uid group=sudo/' /etc/pam.d/su
grep -qE '^auth[[:space:]]+required[[:space:]]+pam_wheel\.so use_uid group=sudo$' /etc/pam.d/su
