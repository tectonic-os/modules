FROM rootfs AS split
RUN mkdir /kernel && \
    bootc container split-kernel-and-rootfs --rootfs / --output /kernel

FROM rootfs AS sealed-uki
RUN --mount=type=bind,from=split,target=/target \
    --mount=type=bind,from=split,source=/kernel,target=/kernel \
    --mount=type=bind,from=ctx,source=@MODULE@/canary,target=/canary,ro \
    --mount=type=secret,id=mok_privkey,target=/run/secrets/mok_privkey,required=false \
    --mount=type=tmpfs,target=/var/tmp \
    --mount=type=tmpfs,target=/tmp <<'SH'
set -euxo pipefail

expected=$(cat /canary/digest)
expected_version=$(cat /canary/bootc-version)
cp -a /canary/root /tmp/canary
mkdir -p /tmp/canary/boot /tmp/canary/sysroot
find /tmp/canary -type d -exec chmod 0755 {} +
find /tmp/canary -type f -exec chmod 0644 {} +
find /tmp/canary -exec touch -h -d @0 {} +
actual=$(bootc container compute-composefs-digest /tmp/canary)
actual_version=$(bootc --version)
if [ "$actual" != "$expected" ]; then
    echo "composefs digest canary moved: $expected ($expected_version) -> $actual ($actual_version)" >&2
    exit 1
fi

mkdir -p /out
kver=$(ls /kernel)
sign=()
if [ -s /run/secrets/mok_privkey ]; then
    openssl x509 -in /usr/share/secureboot/sb_cert.der -inform DER \
        -out /tmp/secureboot.pem -outform PEM
    sign=(
        --signtool sbsign
        --secureboot-private-key /run/secrets/mok_privkey
        --secureboot-certificate /tmp/secureboot.pem
    )
else
    echo "No MOK key supplied, UKI is unsigned."
fi

bootc container ukify \
    --rootfs /target \
    --kernel-dir "/kernel/${kver}" \
    -- \
    --output "/out/${kver}.efi" \
    "${sign[@]}"
SH

FROM split
COPY --from=sealed-uki /out/*.efi /boot/EFI/Linux/
