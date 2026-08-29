# fedora-bootc is a general base, so it ships for server, cloud and enterprise.
# This deboat removes packages unneccessery for desktop users.
dnf5 remove -y --noautoremove \
    qemu-user-static-alpha qemu-user-static-arm qemu-user-static-hexagon \
    qemu-user-static-hppa qemu-user-static-loongarch64 qemu-user-static-m68k \
    qemu-user-static-microblaze qemu-user-static-mips qemu-user-static-or1k \
    qemu-user-static-ppc qemu-user-static-riscv qemu-user-static-s390x \
    qemu-user-static-sh4 qemu-user-static-sparc qemu-user-static-x86 \
    qemu-user-static-xtensa

# Server crash analysis.
dnf5 remove -y --noautoremove kdump-utils kexec-tools makedumpfile

# Enterprise directory auth: Active Directory, FreeIPA, Kerberos, LDAP.
dnf5 remove -y --noautoremove sssd-ad sssd-common-pac sssd-ipa sssd-krb5 sssd-ldap

# Reads cloud provider metadata at 169.254.169.254 to configure interfaces.
dnf5 remove -y --noautoremove NetworkManager-cloud-setup
