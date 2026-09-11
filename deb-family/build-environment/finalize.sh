rm /usr/sbin/policy-rc.d
if [ -e /usr/sbin/policy-rc.d.bak ]; then
    mv /usr/sbin/policy-rc.d.bak /usr/sbin/policy-rc.d
fi

if [ -d /etc/apt/tect-build ]; then
    mv /etc/apt/tect-build/*.sources /etc/apt/sources.list.d/ 2> /dev/null || true
    rmdir /etc/apt/tect-build
fi
rm -f /etc/apt/apt.conf.d/80-tect-build
