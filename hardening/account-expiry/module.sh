# An edit rather than an overlay: the base sets HOME=/var/home in this file.
sed -i '/^INACTIVE=/d' /etc/default/useradd
echo 'INACTIVE=30' >> /etc/default/useradd
