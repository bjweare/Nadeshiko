# Should be sourced.

#  bahelite_dialog.sh
#  Wrapper for *dialog  programs to put main script name in the window title.

# Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	echo 'Must be sourced from bahelite.sh.' >&2
	return 5
}

# Avoid sourcing twice
[ -v BAHELITE_MODULE_DIALOG_VER ] && return 0
#  Declaring presence of this module for other modules.
BAHELITE_MODULE_DIALOG_VER='2.0'


 # Makes sure, that every *dialog window has a proper window title.
#  If --title "some title" is specified, then “ – $MY_DESKTOP_NAME” is added
#    to it in order to indicate, to which program this dialog belongs.
#    If the --title key is not specified, it is added, and the title string
#    is made equal to “$MY_DESKTOP_NAME”, i.e. the name of the running script.
#  This function expects, that you define a global variable “dialog”, where
#    you put the name of the binary, e.g. Xdialog, zenity, kdialog…
#    and expand REQUIRED_UTILS array with $dialog.
#  $1..n – whatever you would pass to your dialog program.
#
dialog() {
	[ -v dialog ] \
		|| err "“dialog” variable isn’t set, not running any dialog."
	which $dialog &>/dev/null \
		|| err "Dialog program “$dialog” is not available on this system."
	local i args=( "$@" )  title_string
	argc=${#args[@]}
	for ((i=0; i<argc; i++)); do
		[[ "${args[i]}" =~ ^--title(=(.+)|)$ ]] && {
			if [ "${BASH_REMATCH[2]}" ]; then
				title_string="${BASH_REMATCH[2]}"
				unset args[i]
			else
				title_string=${args[i+1]}
				unset args[i] args[i+1]
				let ++i
			fi
		}
	done
	[ "${title_string:-}" ] \
		&& title_string+=" – $MY_DESKTOP_NAME" \
		|| title_string="$MY_DESKTOP_NAME"
	command -p $dialog --title "$title_string" "${args[@]}"
	return $?  # ←!
}

 # Since *dialog programs are often used inside a subshell, like
#    my_var=$(Xdialog --inputbox "Enter value:" 200x100)
#  the function must be exported, or the subshell will not use
#  our hook function above.
#
export -f dialog

return 0