# Should be sourced.

#  bahelite_directories.sh
#  Functions to set paths to internal and user directories.
#  © deterenkelt 2019

#  Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	echo 'Must be sourced from bahelite.sh.' >&2
	return 5
}
. "$BAHELITE_DIR/bahelite_messages.sh" || return 5

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_DIRECTORIES_VER ] && return 0
#  Declaring presence of this module for other modules.
BAHELITE_MODULE_DIRECTORIES_VER='1.1.3'



                     #  Paths within user’s $HOME  #

[ -v XDG_CONFIG_HOME ]  \
	|| export XDG_CONFIG_HOME="$HOME/.config"
[ -v XDG_CACHE_HOME ]  \
	|| export XDG_CACHE_HOME="$HOME/.cache"
[ -v XDG_DATA_HOME ]  \
	|| export XDG_DATA_HOME="$HOME/.local/share"


 # Prepares config directory with respect to XDG
#  [$1] – script name, whose config directory will be used.
#         If unset, uses $MYNAME. (Useful for when there’s a script suite,
#         which should use same directory, or when one script is a testing
#         suite for another and should be able to retrieve other script’s
#         config directory).
#
prepare_confdir() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	[ -v BAHELITE_CONFDIR_PREPARED ] && {
		info "Config directory is already prepared!"
		return 0
	}
	[ "${1:-}" ] \
		&& local own_subdir="$1" \
		|| local own_subdir="${MYNAME%.*}"
	[ -v CONFDIR ] || CONFDIR="$XDG_CONFIG_HOME/$own_subdir"

	bahelite_check_directory "$CONFDIR" 'Config'
	declare -g BAHELITE_CONFDIR_PREPARED=t
	return 0
}


 # Prepares cache directory with respect to XDG
#  [$1] – script name, whose cache directory will be used.
#         If unset, uses $MYNAME. (Useful for when there’s a script suite,
#         which should use same directory, or when one script is a testing
#         suite for another and should be able to retrieve other script’s
#         cache directory).
#
prepare_cachedir() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	[ -v BAHELITE_CACHEDIR_PREPARED ] && {
		info "Cache directory is already prepared!"
		return 0
	}
	local own_subdir
	[ "${1:-}" ] \
		&& local own_subdir="$1" \
		|| local own_subdir="${MYNAME%.*}"
	[ -v CACHEDIR ] || CACHEDIR="$XDG_CACHE_HOME/$own_subdir"

	bahelite_check_directory "$CACHEDIR" 'Cache'
	declare -g BAHELITE_CACHEDIR_PREPARED=t
	return 0
}


 # Prepares data directory with respect to XDG
#  [$1] – script name, whose data directory will be used.
#         If unset, uses $MYNAME. (Useful for when there’s a script suite,
#         which should use same directory, or when one script is a testing
#         suite for another and should be able to retrieve other script’s
#         data directory).
#
prepare_datadir() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	[ -v BAHELITE_DATADIR_PREPARED ] && {
		info "Data directory is already prepared!"
		return 0
	}
	[ "${1:-}" ] \
		&& local own_subdir="$1" \
		|| local own_subdir="${MYNAME%.*}"
	[ -v DATADIR ] || DATADIR="$XDG_DATA_HOME/$own_subdir"

	bahelite_check_directory "$DATADIR" 'Data'
	declare -g BAHELITE_DATADIR_PREPARED=t
	return 0
}



                      #   System directories   #

 # These are the directories being the part of the source code.
#  Bahelite supports two ways of finding them, depending on how
#  the source is installed:
#
#  - IF THE SOURCE REMAINS A SOLID PIECE, e.g. it is downloaded by the user
#    (or cloned with some version control system) somewhere under his own
#    $HOME, the source directories are searched in the same directory, where
#    the executable file – mother script for bahelite – itself resides.
#
#  - IF THE SOURCE IS SPLIT, because a package manager (or a Linux enthusiast)
#    utilised some Makefile, and now the files are spread across several direc-
#    tories under the the disk root, e.g. executables go to /usr/bin, libra-
#    ries go to /lib/…/…,  other files are placed in /usr/share/,  then the
#    source subdirectories are searched by the common paths such as the ones
#    just mentioned – these paths are hardcoded – but source subdirectories
#    are expected to be within a subfolder named like ${MY_NAME%.*} (a com-
#    mon policy for the files in /usr/share, but not so common for e.g. /lib).
#
#  Bahelite tries to intellectually determine, whether the installation is
#    a solid, standalone or it is split across the root filesystem. For that
#    MYDIR is tested to be /usr/local/bin or /usr/bin, and if it appears to be
#    one of them, BAHELITE_SPLIT_INSTALLATION is set.
#  This variable prevents search for source subdirectories in MYDIR. In the
#    case when a user might install the main program with both ways – with a
#    package manager and locally, calling the executable from the local instal-
#    lation should not look into system directories, and stay in MYDIR instead.
#    And vice versa, a split installation should not try to find source subdi-
#    rectories in $PATH, around the executable.
#
#  Possible paths for source subdirectories are as follows:
#    LIBDIR:
#    /usr/local/lib/${MY_NAME%.*}
#    /usr/lib/${MY_NAME%.*}
#    /usr/share/${MY_NAME%.*}/lib
#    <MYDIR>/lib
#
#    MODULESDIR:
#      (Modules are essentially libraries too, the separation exists
#       for the ability to separate the ones developed specifially for this
#       mother script/main program from the libs attached as third-party –
#       those may have their own licences and update hooks, so they are
#       better kept separately on the development stage. For an installer
#       or a Makefile there is no difference between “libs” and “modules”.)
#    /usr/local/lib/${MY_NAME%.*}
#    /usr/lib/${MY_NAME%.*}
#    /usr/share/${MY_NAME%.*}/modules
#    <MYDIR>/modules
#
#    Whatever else: EXAMPLECONFDIR, RESOURCESDIR and whatever else you invent.
#    /usr/local/share/<MY_DISPLAY_NAME>/<whatevername>
#    /usr/share/<MY_DISPLAY_NAME>/<whatevername>
#    <MYDIR>/<whatevername>
#
#  To the packager (the human) – you can split the source files either
#    in a simple, or in a complex way.
#         Simple split           │     Complex split
#     ───────────────────────────┼────────────────────────────
#         “binaries”             │     “binaries”
#         “everything else”      │     “libs and modules”
#                                │     “resources”
#    If you go the “simple split” way,
#      1. Copy the executables to /usr/bin or /usr/local/bin.
#      2. Create directory /usr/share/${MYNAME%.*}/  and copy the source sub-
#         directories in there AS THEY ARE, do not rename them or delete.
#    If you go the “complex split” way,
#      1. Copy the executables to /usr/bin or /usr/local/bin.
#      2. Put libraries from lib/ and modules/ to a subdirectory under
#         /usr/lib or /usr/local/lib, that is create /use/lib/${MYNAME%.*}/
#         and copy the libraries from lib/ (the “lib” in the source directory)
#         in there. DO NOT CREATE a lib/ within lib/ (e.g. /usr/lib/my-prog/lib/).
#      3. Copy the rest of the source directories (various “res”, “misc”)
#         AS THEY ARE to /usr/share/${MYNAME%.*} or /usr/local/share/${MYNAME%.*}/
#         (create that directory beforehand). Here DO LEAVE the original name
#         or the subdirectory:
#           e.g. /usr/share/my-prog/resources  — OK
#                /usr/share/my-prog/<the content of “resources/”>  — NOT OK.
#         This is true for the irregular subdirectories, man pages, icons,
#         fonts should go to their respective directories under /usr/share
#         (or /usr/local/share) – since the burden of making those files acces-
#         sible relies on the OS, the main script should not bother about the
#         paths. However, if the main script will need these files in the run-
#         time and it cannot rely on the provision of paths by OS, it better
#         remain the source directory structure under /usr/share
#         or /usr/local/share.
#
#  Notes
#  1. The author doesn’t believe, that somebody would use Bahelite for essen-
#     tial system software, hence the basic directories like /bin and /lib
#     are never searched.
#  2. For all subdirectories both singular and plural forms are valid and will
#     be found. The variable name set will be whatever is passed to set_source_
#     dir(), so if you use the set_libdir() alias for example, the variable
#     will still be created as LIBDIR. To create it as LIBSDIR do not use an
#     alias and use set_source_dir() directly with the preferred variable name.


 # Helpers for setting the most common source subdirectories.
#
set_libdir() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	__set_source_dir LIBDIR "$@"
}
set_modulesdir() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	__set_source_dir MODULESDIR "$@"
}
set_exampleconfdir() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	__set_source_dir EXAMPLECONFDIR "$@"
}
set_resdir() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	__set_source_dir RESDIR "$@"
}
set_sourcedir() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	__set_source_dir "$@"
}
#
#
 # Finds paths for the subdirectories of the source code and sets these
#  paths to global variables.
#  $1  – subdirectory name and also the name of the global variable, that will
#        hold the path. I.e. you give the variable name, and the subdirectory
#        name is found by making it lowercase and stripping “dir” from the end.
# [$2] – a custom subdirectory name to use in place of $MYNAME
#        Alike to $1 in prepare_cachedir() above.
#
__set_source_dir() {
	local varname="${1^^}"  own_subdir="${2:-$MYNAME}"  dir  possible_paths=()
	local whats_the_dir="${varname,,}"   #  LIBDIR → libdir
	whats_the_dir=${whats_the_dir%dir}   #           libdir → lib
	own_subdir=${own_subdir%.*}          #  my-prog.sh → my-prog
	if [ -v BAHELITE_SPLIT_INSTALLATION ]; then
		case "$whats_the_dir" in
			lib|module)
			;&
			libs|modules)
				possible_paths+=(
					"/usr/local/lib/$own_subdir"
					"/usr/lib/$own_subdir"
					"/usr/share/$own_subdir/$whats_the_dir"
				)
				;;
			*)
				possible_paths+=(
					"/usr/local/share/$own_subdir/$whats_the_dir"
					"/usr/local/share/$own_subdir/${whats_the_dir}s"
					"/usr/share/$own_subdir/$whats_the_dir"
					"/usr/share/$own_subdir/${whats_the_dir}s"
				)
				;;
		esac
	else
		possible_paths=(
			"$MYDIR/$whats_the_dir"
			"$MYDIR/${whats_the_dir}s"
		)
	fi
	for dir in "${possible_paths[@]}"; do
		[ -d "$dir" ] && {
			bahelite_check_module_verbosity \
				&& info "$varname = $dir"
			declare -g $varname="$dir"
			break
		}
	done
	[ -v "$varname" ] || err "Cannot find directory for $varname."
	return 0
}


 # Makes sure, that a directory exists and has R/W permissions.
#  $1 – path to the directory.
#  $2 – the purpose like “config” or “logging”. It is used only in the
#       error message.
#
bahelite_check_directory() {
	#  Internal! No xtrace_off/on needed!
	local dir="${1:-}" purpose="${2:-}"
	[ -v purpose ] && purpose="${purpose,,}"
	if [ -d "$dir" ]; then
		[ -r "$dir" ] \
			|| err "${purpose^} directory “$dir” isn’t readable."
		[ -w "$dir" ] \
			|| err "${purpose^} directory “$dir” isn’t writeable."
	else
		mkdir -p "$dir" || err "Couldn’t create $purpose directory “$dir”."
	fi
	return 0
}



[[ "$MYDIR" =~ (/usr/bin|/usr/local/bin) ]]  \
	&& BAHELITE_SPLIT_INSTALLATION=t

export -f  prepare_confdir  \
           prepare_cachedir  \
           prepare_datadir  \
           __set_source_dir  \
               set_libdir  \
               set_modulesdir  \
               set_exampleconfdir  \
               set_resdir  \
               set_sourcedir  \
           bahelite_check_directory

return 0