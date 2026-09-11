# gdm3's postinst points display-manager.service at the gdm3.service alias, which
# validate-image does not follow; finalize's `systemctl enable` relinks gdm.service.
rm -f /etc/systemd/system/display-manager.service
