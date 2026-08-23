rm /usr/sbin/policy-rc.d
if [ -e /usr/sbin/policy-rc.d.bak ]; then
	mv /usr/sbin/policy-rc.d.bak /usr/sbin/policy-rc.d
fi
