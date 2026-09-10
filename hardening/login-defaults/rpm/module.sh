# The base only tightens a umask of 0, and does it behind a test, so the value
# never begins a line. An unconditional line is the whole point.
sed -i 's/\bumask 0\?22\b/umask 027/g' /etc/bashrc
grep -qE '^[[:space:]]*umask[[:space:]]' /etc/bashrc || printf 'umask 027\n' >> /etc/bashrc
