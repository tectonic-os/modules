source /ctx/lib/sign-helpers.sh

openssl x509 -in "$MOK_CERT_DER" -inform DER \
    -out /usr/share/secureboot/sb_cert.pem -outform PEM
if mok_signing_available; then
    sign_vmlinuz /usr/lib/systemd/boot/efi/systemd-bootx64.efi
    install -D -m 0644 /dev/null /usr/share/secureboot/signed
else
    echo "No MOK key supplied, systemd-boot is unsigned."
fi

# The marker the image's own validators and the installer read: this build has
# the PCR signing key, so the tail must produce a UKI carrying the policy, and
# first-boot TPM2 enrolment binds to it. Without the key there is no marker and
# every chain keeps PCR 7. The private half must be the committed public half's
# pair, or the policy the UKI signs would never verify on a machine.
if [ -s /run/secrets/pcr_privkey ]; then
    if ! openssl pkey -pubout -in /run/secrets/pcr_privkey \
        | cmp -s - /usr/share/secureboot/pcr.pub; then
        echo "the PCR private key does not match /usr/share/secureboot/pcr.pub" >&2
        exit 1
    fi
    install -D -m 0644 /usr/share/secureboot/pcr.pub \
        /usr/share/secureboot/pcr-policy.pem
else
    echo "No PCR signing key supplied, the image carries no PCR policy."
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
