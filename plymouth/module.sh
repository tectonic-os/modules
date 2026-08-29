# Fedora and Debian ship plymouth-set-default-theme. Ubuntu does not, and picks
# the theme through the alternatives system instead, where the spinner theme
# ships on disk but arrives unregistered.
theme=spinner

if command -v plymouth-set-default-theme >/dev/null; then
	plymouth-set-default-theme "$theme"
else
	file="/usr/share/plymouth/themes/${theme}/${theme}.plymouth"
	update-alternatives --install /usr/share/plymouth/themes/default.plymouth \
		default.plymouth "$file" 200
	update-alternatives --set default.plymouth "$file"
fi
