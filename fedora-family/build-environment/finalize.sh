# Nothing to put back where the base had no systemd: the one a module
# installed during this build is the real binary already.
if [ -e /usr/bin/systemctl.bak ]; then
    rm -f /usr/bin/systemctl
    mv /usr/bin/systemctl.bak /usr/bin/systemctl
fi
