source /ctx/lib/sign-helpers.sh

openssl x509 -in "$MOK_CERT_DER" -inform DER \
    -out /usr/share/secureboot/sb_cert.pem -outform PEM
if mok_signing_available; then
    sign_vmlinuz /usr/lib/systemd/boot/efi/systemd-bootx64.efi
    install -D -m 0644 /dev/null /usr/share/tectonic/secureboot-signed
else
    echo "No MOK key supplied, systemd-boot is unsigned."
fi

install -D -m 0644 /usr/lib/systemd/boot/efi/systemd-bootx64.efi \
    /boot/EFI/systemd/systemd-bootx64.efi
install -D -m 0644 /usr/lib/systemd/boot/efi/systemd-bootx64.efi \
    /boot/EFI/BOOT/BOOTX64.EFI
bootc --version > /usr/share/tectonic/composefs-sealer-version
install -D -m 0644 "$MODDIR/canary/digest" \
    /usr/share/tectonic/composefs-canary-digest
if [ -n "${BOOT_CHAIN:-}" ]; then
    printf '%s\n' "$BOOT_CHAIN" > /usr/share/tectonic/boot-chain
fi

rm -rf /usr/lib/efi/grub2
dnf5 -y remove --noautoremove bootupd
