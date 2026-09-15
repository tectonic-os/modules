source /ctx/lib/sign-helpers.sh

case "${BOOT_CHAIN:-}" in
    uki-shim)
        install -D -m 0755 "$MODDIR/install-shim.sh" \
            /usr/libexec/secureboot-enrolment
        ;;
    uki-db)
        if ! mok_signing_available; then
            echo "No MOK key supplied, firmware enrollment files are absent."
            exit 0
        fi

        work=$(mktemp -d)
        openssl x509 -in "$MOK_CERT_DER" -inform DER \
            -out "$work/secureboot.pem" -outform PEM
        guid=$(uuidgen)
        for name in PK KEK db; do
            cert-to-efi-sig-list -g "$guid" "$work/secureboot.pem" "$work/$name.esl"
            sign-efi-sig-list -g "$guid" -k "$MOK_KEY" -c "$work/secureboot.pem" \
                "$name" "$work/$name.esl" "$work/$name.auth"
            install -D -m 0644 "$work/$name.auth" \
                "/usr/lib/bootc/install/secureboot-keys/auto/$name.auth"
        done
        rm -rf "$work"
        ;;
    *)
        echo "No owner-signed boot chain declared, enrollment artifacts are absent."
        ;;
esac
