source /ctx/lib/kernel-helpers.sh

mkdir -p /usr/lib/kernel-build
if [ "$KERNEL" = "stock" ]; then
    echo "KERNEL=stock: keeping the Fedora base kernel, skipping CachyOS packages."
    echo "kernel-core" > /usr/lib/kernel-build/kernel-package
else
    dnf5 -y --setopt=tsflags=noscripts install --enablerepo="$COPR_BIESZCZADERS_KERNEL_CACHYOS" \
        kernel-cachyos \
        kernel-cachyos-core \
        kernel-cachyos-modules \
        kernel-cachyos-devel-matched

    echo "kernel-cachyos-core" > /usr/lib/kernel-build/kernel-package

    dnf5 -y install --enablerepo="$COPR_BIESZCZADERS_KERNEL_CACHYOS_ADDONS" \
        ananicy-cpp \
        cachyos-ananicy-rules \
        cachyos-settings \
        scx-scheds \
        scx-tools \
        bore-sysctl

    KVER="$(kver)"

    depmod "$KVER"

    dnf5 -y install sbsigntools openssl

    source /ctx/lib/sign-helpers.sh
    if mok_signing_available; then
        SIGN_FILE="/usr/src/kernels/${KVER}/scripts/sign-file"
        sign_modules_under "/usr/lib/modules/${KVER}" "$SIGN_FILE"
        sign_vmlinuz "/usr/lib/modules/${KVER}/vmlinuz"
    else
        echo "No MOK key supplied, kernel and modules are unsigned."
    fi

    dnf5 -y remove --noautoremove kernel-cachyos-devel-matched sbsigntools

    dnf5 -y remove --noautoremove kernel kernel-core kernel-modules kernel-modules-core
fi
