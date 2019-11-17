#  Should be sourced.

#  xdg_directories.sh
#  Generic functions to set and create paths to main script’s subdirectories
#  within  XDG_*_HOME  and  XDG_*_DIR  paths. Work with particular paths is
#  covered in the “any-xdg-dir.common.sh” module.
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
[ -v BAHELITE_MODULE_XDG_DIRECTORIES_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_XDG_DIRECTORIES_VER='1.0'
bahelite_load_module 'check_directory' || return $?


(( $# != 0 )) && {
	echo "Bahelite module “xdg_directories” doesn’t take arguments!"  >&2
	[ "$*" = help ]  \
		&& return 0  \
		|| return 4
}


BAHELITE_KNOWN_XDG_PATHS=(
	 # Main script’s configuration file(s).
	#
	XDG_CONFIG_HOME

	 # Holds temporary files, that must persist between runs or may be needed
	#    after the program is closed. In any way, files in here are not essen-
	#    tial and erasing them is not critical. The user normally shouldn’t
	#    have any need to look in this folder, unless they are debugging
	#    or solving an issue.
	#  Bahelite uses this directory to store log files.
	#
	XDG_CACHE_HOME

	 # Holds files, that are important for the user. He might have authored
	#  some of them. Unlike with XDG_CACHE_HOME, the user may want to look
	#  into this folder from time to time, he may also want to preserve files
	#  in it when moving to another system. The files may be:
	#    - backup and autosave files;
	#    - plugins, add-ons, materials
	#     (graphical editors store brushes in this folder);
	#    - various data files or samples that serve as input for the main
	#      script (some scientific dumps and catalogues come to mind).
	#
	XDG_DATA_HOME

	XDG_DESKTOP_DIR
	XDG_DOWNLOAD_DIR
	XDG_PICTURES_DIR
	XDG_MUSIC_DIR
	XDG_VIDEOS_DIR
	XDG_DOCUMENTS_DIR
	XDG_TEMPLATES_DIR
	XDG_PUBLICSHARE_DIR

	 # Use it, if your temporary files are too large (exceed 1 GiB or whatever
	#  your user’s /tmp is capable to hold.) For everything smaller use TMPDIR,
	#  which is always available.
	#
	XDG_RUNTIME_DIR
)
BAHELITE_KNOWN_XDG_PATHS_REGEX="^($(
	IFS='|';  echo "${BAHELITE_KNOWN_XDG_PATHS[*]}"
))$"


#  Try to read paths as they set by user.
source "$HOME/.config/user-dirs.dirs" || true

#  Declare all variable as global and for export.
#  This doesn’t set the variables, only defines, how they should be treated.
for xdg_path in "${BAHELITE_KNOWN_XDG_PATHS[@]}"; do
	declare -gx $xdg_path
done
unset xdg_path


__list_known_xdg_paths() {
	local varname
	for varname in "${BAHELITE_KNOWN_XDG_PATHS[@]}"; do
		echo "$varname"
	done
	return 0
}


 # Verifies, that the XDG variable exists and holds an existing path.
#
#  $1 – variable name, e.g. XDG_CONFIG_HOME
#  $2 – default path to assign, if the variable is not set yet or holds
#       a non-existing path.
#
__check_xdg_directory() {
	local xdg_varname="$1"
	local xdg_default_path="$2"

	[[ "$xdg_varname" =~ $BAHELITE_KNOWN_XDG_PATHS_REGEX ]]  \
		|| err "Unknown XDG variable name: “$xdg_varname”.
		        Known paths are:
		        $(__list_known_xdg_paths)"

	declare -gx "$xdg_varname"

	[ -v "$xdg_varname" ] && {
		local -n varval="$xdg_varname"
		[ -d "$varval" ] && [ -r "$varval" ] && [ -w "$varval" ]  \
			&& return 0
	}

	declare -gx $xdg_varname="$xdg_default_path"
	[ -d "$xdg_default_path" ] || {
		mkdir -m 0700 -p "$xdg_default_path"  \
			|| err "Couldn’t create directory “$xdg_default_path” for $xdg_varname."
	}

	return 0
}


 # Creates own subdirectory within an XDG path for the main script.
#  Sets it to a new global variable. Own path never coincides with the common
#  XDG path for XDG_*_HOME parents, and does coincide by default, when the
#  parent is an XDG_*_DIR directory (but may optionally use a subdirectory
#  too). Subdirectory name is by default $MYNAME_NOEXT, but may be custom.
#
#   $1  – XDG variable, that holds path to the parent directory,
#           e.g. XDG_CACHE_HOME or XDG_DESKTOP_DIR.
#   $2  – name of the global variable for the main script’s own subdirectory,
#           that Bahelite should create and use
#  [$3] – name of the main script’s subdirectory, that should be added to the
#           common XDG path specified by the $1. The path in $1 and added $3
#           will comprise the own subdirectory path, that will be assigned
#           to the variable specified in $2.
#         By default, any-xdg-dir.common.sh  sets this parameter for every
#           subdirectory, whose parent is XDG_*_HOME, and for those whose
#           parent is XDG_*_DIR it omits this parameter. (You always need
#           own subdirectory within ~/.config/…, but you don’t want any
#           garbage subdirectory under ~/Desktop/…)
#
__prepare_xdg_subdir() {
	local xdg_parent_varname="$1"
	local varname="$2"
	local own_subdir
	local own_dir
	local purpose

	[[ "$xdg_parent_varname" =~ $BAHELITE_KNOWN_XDG_PATHS_REGEX ]]  \
		|| err "Unknown XDG variable name: “$xdg_parent_varname”.
		        Known paths are:
		        $(__list_known_xdg_paths)"

	local -n xdg_parent_path="$xdg_parent_varname"

	[ "${3:-}" ] && own_subdir="$3"

	if [ -v "$varname" ]; then
		warn "$varname is already set!"
		return 0
	else
		own_dir="$xdg_parent_path/${own_subdir:-}"
		declare -gx $varname="$own_dir"
	fi

	purpose="${xdg_parent_varname#XDG_}"
	purpose="${purpose%_HOME}"
	purpose="${purpose%_DIR}"
	__check_directory "$own_dir" "$purpose"

	return 0
}



return 0