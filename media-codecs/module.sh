OVERRIDES=(
    intel-gmmlib
    intel-mediasdk
    intel-vpl-gpu-rt
    libheif
    libva
    libva-intel-media-driver
    mesa-dri-drivers
    mesa-filesystem
    mesa-libEGL
    mesa-libGL
    mesa-libgbm
    mesa-vulkan-drivers
)
dnf5 distro-sync --skip-unavailable -y --repo='fedora-multimedia' "${OVERRIDES[@]}"
dnf5 versionlock add "${OVERRIDES[@]}"

dnf5 install -y mesa-libOpenCL.x86_64
dnf5 versionlock add mesa-libOpenCL

rm -f /usr/share/pipewire/pipewire.conf.d/50-raop.conf
