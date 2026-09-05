# `ssh.service` on both deb families, `sshd.service` on Fedora, and a module
# preset cannot say two things: `files/` is copied unconditionally and every
# line in a `.preset` is applied with a plain `systemctl enable`, so a unit
# that does not exist fails the build. A hook can branch, and hooks run before
# the preset pass, so this lands in the same place a preset line would have.
#
# `ID_LIKE` and not `ID` alone: an Ubuntu derivative names itself and inherits
# `debian` there, and the unit name is a family fact rather than a distro one.
. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
    *" debian "* | *" ubuntu "*) systemctl enable ssh.service ;;
    *) systemctl enable sshd.service ;;
esac
