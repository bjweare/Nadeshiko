#  Should be sourced.

#  any-xdg-dir.common.sh
#
#  All cache/data/config/desktop/downloaddir.sh modules symlink to this one.
#  This module acts in stead of all XDG directory modules – thus there is
#  less code to manage and all differences can be observed in one place.
#
#  Sets paths to program’s own subdirectories within $HOME, such as under
#  ~/.config/…. Paths are created if necessary. New global variables with
#  shorter names are created for the use in Bahelite and in the main script,
#  such as CONFDIR, DATADIR, CACHEDIR, DESKTOPDIR etc.
#
#  © deterenkelt 2019

#  Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	cat <<-EOF  >&2
	Bahelite error on loading module ${BASH_SOURCE##*/}:
	load the core module (bahelite.sh) first.
	EOF
	return 4
}

#  Get the name of the module in whose stead to act
module_name="${BASH_SOURCE##*/}"
module_name="${module_name%.sh}"

#  Avoid sourcing this module twice
[ -v BAHELITE_MODULE_${module_name^^}_VER ] && return 0
#  Declaring presence of this module
declare -grx BAHELITE_MODULE_${module_name^^}_VER='1.0'
bahelite_load_module 'xdg_directories' || return $?



 # Describes what arguments this module takes (if if takes any)
#
__show_usage_any-xdg-dir_module() {
	cat <<-EOF  >&2
	Bahelite module “$module_name” arguments:

	subdir=custom_directory_name
	    The name of the subdirectory to create under XDG parent directory
	    and use. (Specify it when instead of one main script you have
	    a bundle, and every script in it uses the same source subdirectory.)

	use_subdir
	    A shorthand for the subdir option, that specifies the default name
	    for the subdirectory, “$MYNAME_NOEXT”.

	For confdir, datadir and cachedir modules a subdirectory is ALWAYS CREATED,
	   thus the “use_subdir” parameter for them is useless. The “subdir” para-
	   meter can be used to set a custom name (if you have a bunch of scripts
	   and want them all to use one config directory, for example).
	The other modules, that point to XDG directories, DO NOT CREATE a subdirec-
	   tory by default (because you want a custom subdirectory under ~/.config/…
	   but do not want a garbage directory in ~/Desktop/…). However, with the
	   parameters above it’s possible to have custom subdirectories with these
	   modules too.
	EOF
	return 0
}
#  No export: init stage function.
#  Throwaway function: it is called only when the execution is going to stop,
#  in case of an error or because module was called with “help” as a parameter.
#  It is okay for this function to be redefined each time the module loads.



default_own_subdir_name="${MY_BUNCH_NAME:-$MYNAME_NOEXT}"

for arg in "$@"; do
	case "$arg" in
		help)
			__show_usage_any-xdg-dir_module
			exit 0
			;;
		'')
			;;
		subdir=*)
			requested_own_subdir_name="${arg#subdir=}"
			;;
		use_subdir)
			requested_default_own_subdir_name="$MYNAME_NOEXT"
			;;
		*)
			__show_usage_any-xdg-dir_module
			err "Wrong argument “$arg” for the module “$module_name”."
	esac
done

case "$module_name" in
	confdir)
		xdg_parent_varname='XDG_CONFIG_HOME'
		xdg_parent_default_path="$HOME/.config"
		;;&
	cachedir)
		xdg_parent_varname="XDG_CACHE_HOME"
		xdg_parent_default_path="$HOME/.cache"
		;;&
	datadir)
		xdg_parent_varname="XDG_DATA_HOME"
		xdg_parent_default_path="$HOME/.local/share"
		;;&

	desktopdir)
		xdg_parent_varname="XDG_DESKTOP_DIR"
		xdg_parent_default_path="$HOME/Desktop"
		;;&
	downloaddir)
		xdg_parent_varname="XDG_DOWNLOAD_DIR"
		xdg_parent_default_path="$HOME/Download"
		;;&
	picsdir)
		xdg_parent_varname="XDG_PICTURES_DIR"
		xdg_parent_default_path="$HOME/Pictures"
		;;&
	musicdir)
		xdg_parent_varname="XDG_MUSIC_DIR"
		xdg_parent_default_path="$HOME/Music"
		;;&
	videosdir)
		xdg_parent_varname="XDG_VIDEOS_DIR"
		xdg_parent_default_path="$HOME/Videos"
		;;&
	docsdir)
		xdg_parent_varname="XDG_DOCUMENTS_DIR"
		xdg_parent_default_path="$HOME/Documents"
		;;&
	templatesdir)
		xdg_parent_varname="XDG_TEMPLATES_DIR"
		xdg_parent_default_path="$HOME/Templates"
		;;&
	pubsharedir)
		xdg_parent_varname="XDG_PUBLICSHARE_DIR"
		xdg_parent_default_path="$HOME/Public"
		;;&


	confdir)
	;&
	cachedir)
	;&
	datadir)
		if [ -v requested_own_subdir_name ]; then
			own_subdir_name="$requested_own_subdir_name"
		elif [ -v requested_default_own_subdir_name ]; then
			own_subdir_name="$default_own_subdir_name"
		else
			own_subdir_name="$default_own_subdir_name"
		fi
		;;

	desktopdir)
	;&
	downloaddir)
	;&
	picsdir)
	;&
	musicdir)
	;&
	videosdir)
	;&
	docsdir)
	;&
	templatesdir)
	;&
	pubsharedir)
		if [ -v requested_own_subdir_name ]; then
			own_subdir_name="$requested_own_subdir_name"
		elif [ -v requested_default_own_subdir_name ]; then
			own_subdir_name="$default_own_subdir_name"
		else
			unset own_subdir_name
		fi
		;;

	any-xdg-dir.common)
		#  When Bahelite modules are loaded not selectively, this module
		#  might be loaded too – as is, – but that must be avoided.
		return 0
esac
bahelite_varname="${module_name^^}"



                         #  Postload job  #

#  Now to have a postload job we essentially need to construct a function
#  with a unique name in runtime. (Unique name is necessary to have, so that
#  other modules, that depends on particular directories, might depend on
#  their respective prepare_*dir() functions.)
#
#  Bash doesn’t allow to construct functions in runtime. There’s no such
#  thing like with variables, where it’s possible to do stuff like
#      declare  my_var_number_${i}=$j
#  But we can construct the function, dump it to a sourcable shell file
#  and source that!
temp_func_file=$(
	mktemp --tmpdir=$TMPDIR  bahelite.prepare_${module_name}_func.XXX
)

cat <<EOF  >"$temp_func_file"
#  Should be sourced.

#  ${temp_func_file##*/}
#  A Bahelite postload job file. Generated by the any-xdg-dir.common.sh module
#  at runtime. This function is created from a template, because there are
#  11 directories. So instead of maintaining 11 files with small differences
#  between each other, it’s more feasible to just use a template. But due
#  to Bash limitations the function below cannot be created and stored from
#  the code itself – it has to be dumped to a file and sourced. So if you
#  found this file in \$TMPDIR and think that it’s strange – there’s actually
#  nothing weird going on.


 # Creates the requested subdirectory and its XDG parent.
#
prepare_${module_name}() {
	bahelite_xtrace_off  && trap bahelite_xtrace_on RETURN

	__check_xdg_directory "$xdg_parent_varname"  \
	                      ${xdg_parent_default_path@Q}

	__prepare_xdg_subdir  "$xdg_parent_varname"  \
	                      "$bahelite_varname"  \
	                      "${own_subdir_name:-}"
	return 0
}
#  No export: init stage function.
EOF
source "$temp_func_file"
#  ^ If you think this is bad, consider using eval,
#    like in e.g. this solution of an Euler problem: https://git.io/JeVqK

BAHELITE_POSTLOAD_JOBS+=( "prepare_${module_name}" )

unset  module_name  \
       arg  \
       xdg_parent_varname  \
       xdg_parent_default_path  \
       bahelite_varname  \
       own_subdir_name  \
       default_own_subdir_name  \
       requested_own_subdir_name  \
       requested_default_own_subdir_name  \
       temp_func_file

return 0