# A hook rather than `module.sh`, because `pam-auth-update` reads the profiles
# the overlay ships and a module's overlay is copied after its `module.sh` runs.
# The finalize layer is below every module layer, so by here they are on disk.
#
# Fedora's authselect puts pam_faillock and pam_pwquality in the stack; on a deb
# family nothing does. `pam_faillock.so` is in libpam-modules and ships no
# `pam-configs` profile of its own, so `/etc/security/faillock.conf` is read
# only once these put it in `common-auth`. Three profiles rather than one
# because pam_faillock needs an entry on each side of pam_unix and a third that
# a success reaches: `preauth` above it, `authfail` below, and `authsucc` in an
# Additional block, which is what clears the tally on a good login.
pam-auth-update --package
grep -q 'pam_faillock.so preauth' /etc/pam.d/common-auth
grep -q 'pam_faillock.so authfail' /etc/pam.d/common-auth
grep -q 'pam_faillock.so authsucc' /etc/pam.d/common-auth
grep -q 'pam_faillock.so' /etc/pam.d/common-account
grep -q 'pam_pwquality.so' /etc/pam.d/common-password

# `dictcheck = 1` needs a cracklib dictionary, and without one **every password
# change fails** -- `pam_pwquality` returns "error loading dictionary" and
# `chpasswd` exhausts its retries. Fedora gets one from `cracklib-dicts` at
# `/usr/share/cracklib/pw_dict`, which is where libpwquality looks by default
# there. On a deb family the compiled-in default is `/var/cache/cracklib`, and
# that path is a build cache mount here and machine state on a bootc system, so
# a dictionary written to it reaches no running image. The dictionary is built
# into `/usr` instead and `dictpath` is pointed at it.
install -d /usr/share/cracklib
create-cracklib-dict -o /usr/share/cracklib/pw_dict /usr/share/dict/cracklib-small
printf 'dictpath = /usr/share/cracklib/pw_dict\n' >> /etc/security/pwquality.conf
