# The display manager, the first-run wizard and the input-remapper daemon are
# all named differently per family, and finalize applies a module preset with a
# plain `systemctl enable`, so a line naming an absent unit fails the build.
# Name only the ones that are actually here. The static preset beside this file
# carries the units every supported family has, where a missing one should still
# fail loudly.
#
# This runs before the module's files/ overlay lands, so it writes its own file
# rather than appending to that one, and matches the 45-module-*.preset glob
# finalize reads.
mkdir -p /usr/lib/systemd/system-preset

for unit in plasmalogin.service plasma-setup.service sddm.service \
	input-remapper.service input-remapper-daemon.service; do
	if [ -f "/usr/lib/systemd/system/${unit}" ]; then
		echo "enable ${unit}"
	fi
done >/usr/lib/systemd/system-preset/45-module-kde-desktop-variants.preset
