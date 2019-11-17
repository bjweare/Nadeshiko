#  Should be sourced.

#  check_directory.sh
#  Makes sure, that a directory has R/W permissions. Creates it,
#  if it doesn’t exist yet.
#  © deterenkelt 2019

#  Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	cat <<-EOF  >&2
	Bahelite error on loading module ${BASH_SOURCE##*/}:
	load the core module (bahelite.sh) first.
	EOF
	return 4
}

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_CHECK_DIRECTORY_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_CHECK_DIRECTORY_VER='1.0'


(( $# != 0 )) && {
	echo "Bahelite module “check_directory” doesn’t take arguments!"  >&2
	[ "$*" = help ]  \
		&& return 0  \
		|| return 4
}


 # Makes sure, that a directory exists and has R/W permissions.
#  $1 – path to the directory.
#  $2 – the purpose like “config” or “logging”. It is used only in the
#       error message.
#
__check_directory() {
	#  Internal! No xtrace_off/on needed!
	local  dir="${1:-}"
	local  purpose="${2:-}"

	[ -v purpose ] && purpose="${purpose,,}"
	if [ -d "$dir" ]; then
		[ -r "$dir" ]  \
			|| err "${purpose^} directory “$dir” isn’t readable."
		[ -w "$dir" ]  \
			|| err "${purpose^} directory “$dir” isn’t writeable."
	else
		mkdir -p "$dir" || err "Couldn’t create $purpose directory “$dir”."
	fi
	return 0
}
#  No export: init stage function.



return 0