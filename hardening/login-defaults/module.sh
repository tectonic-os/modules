# Edits rather than overlays: both files are rpm-owned and carry much else.
# ENCRYPT_METHOD is deliberately untouched; the base is on yescrypt and the
# benchmark still asks for the weaker SHA512.
set_login_def() {
	sed -i "/^[#[:space:]]*$1\b/d" /etc/login.defs
	printf '%s\t%s\n' "$1" "$2" >> /etc/login.defs
}

set_login_def PASS_MAX_DAYS 60
set_login_def PASS_MIN_DAYS 7
set_login_def PASS_MIN_LEN 15
set_login_def FAIL_DELAY 4
set_login_def UMASK 027

# The base only tightens a umask of 0, and does it behind a test, so the value
# never begins a line. An unconditional line is the whole point.
sed -i 's/\bumask 0\?22\b/umask 027/g' /etc/bashrc
grep -qE '^[[:space:]]*umask[[:space:]]' /etc/bashrc || printf 'umask 027\n' >> /etc/bashrc
