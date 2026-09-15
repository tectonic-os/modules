#!/usr/bin/env bash
set -euxo pipefail

esp=${1:?the mounted EFI system partition is required}
shim=$(find /usr/lib/efi/shim -type f -path '*/EFI/BOOT/BOOTX64.EFI' -print -quit)
mok=$(find /usr/lib/efi/shim -type f -path '*/EFI/fedora/mmx64.efi' -print -quit)
test -n "$shim"
test -n "$mok"

install -D -m 0644 "$shim" "$esp/EFI/BOOT/BOOTX64.EFI"
install -D -m 0644 /usr/lib/systemd/boot/efi/systemd-bootx64.efi \
    "$esp/EFI/BOOT/grubx64.efi"
install -D -m 0644 "$mok" "$esp/EFI/BOOT/mmx64.efi"
install -D -m 0644 /usr/share/secureboot/sb_cert.der \
    "$esp/EFI/BOOT/MOK.cer"
