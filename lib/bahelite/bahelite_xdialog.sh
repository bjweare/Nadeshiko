# Should be sourced.

#  bahelite_xdialog.sh
#  Wrapper for Xdialog to put main script name in the window title.

# Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	echo 'Must be sourced from bahelite.sh.' >&2
	return 5
}

# Avoid sourcing twice
[ -v BAHELITE_MODULE_XDIALOG_VER ] && return 0
#  Declaring presence of this module for other modules.
BAHELITE_MODULE_XDIALOG_VER='1.0'

which Xdialog &>/dev/null || return 0


 # Makes sure, that every Xdialog window has a proper window title.
#  If --title "some title" is specified, “ – $MY_DESKTOP_NAME” is added to it
#    in order to indicate, to which program this dialog belongs.
#  If the --title key is not specified, it is added, and the title string
#    is made equal to “$MY_DESKTOP_NAME”, i.e. the name of the running script.
#  $@ – whatever you would pass to Xdialog.
#
Xdialog() {
	local i args=( "$@" )  title_string
	argc=${#args[@]}
	for ((i=0; i<argc; i++)); do
		[ "${args[i]}" = --title ] && {
			title_string=${args[i+1]}
			unset args[i] args[i+1]
			let ++i
		}
	done
	[ "${title_string:-}" ] \
		&& title_string+=" – $MY_DESKTOP_NAME" \
		|| title_string="$MY_DESKTOP_NAME"
	command -p Xdialog --title "$title_string" "${args[@]}"
	return $?  # ←!
}

 # Since Xdialog is often used inside a subshell, like
#    my_var=$(Xdialog --inputbox "Enter value:" 200x100)
#  the function must be exported, or the subshell will use the binary
#  directly.
#
export -f Xdialog

return 0