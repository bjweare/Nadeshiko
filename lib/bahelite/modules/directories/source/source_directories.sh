#  Should be sourced.

#  source_directories.sh
#  Functions to find and set paths to where main script’s source directories
#    are installed.
#  Paths are found
#    - for a standalone installation – beside the main script (executable .sh
#      file, that loaded Bahelite);
#    - for an installation in the OS (with a Makefile) – in system directories,
#      such as  /usr/(local/)bin, /usr/(local/)lib, /usr/(local/)share.
#  Paths are set to global variables, which names are defined by the symbolic
#    links to the any-source-dir.common.sh, e.g. if “libdir.sh” links to
#    “any-source-dir.common.sh”, then the variable will have name LIBDIR.
#  Path are searched by the same symbolic link name, except the “dir” part
#    is stripped from the name.
#  Symbolic link name may be in singular or plural form: both will be found.
#    The name of the global variable will maintain the form that is given
#    in the symbolic link name (created as given, only the variable name
#    will be in uppercase).
#  Only “libdir.sh”, “libsdir.sh”, “modulesdir.sh”, “moduledir.sh” are searched
#    in /usr/(local/)lib for the “installation into the OS”-way. The rest is
#    searched in /usr/(local/)share. (As that’s how the files are supposed
#    to be installed by a Makefile.) Both “module(s)dir.sh” and “lib(s)dir.sh”
#    use /usr/(local/)lib path, as modules are essentially libraries too.
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

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_SOURCE_DIRECTORIES_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_SOURCE_DIRECTORIES_VER='1.0'


(( $# != 0 )) && {
	echo "Bahelite module “source_directories” doesn’t take arguments!"  >&2
	[ "$*" = help ]  \
		&& return 0  \
		|| return 4
}


                       #   System directories   #

 # These are the directories being the part of the source code.
#  Bahelite supports two ways of finding them, depending on how
#  the source is installed:
#
#  - IF THE SOURCE REMAINS A SOLID PIECE, e.g. it is downloaded by the user
#    (or cloned with some version control system) somewhere under his own
#    $HOME, the source directories are searched in the same directory, where
#    the main script (the mother script for bahelite) itself resides.
#
#  - IF THE SOURCE IS SPLIT, because a package manager (or a Linux enthusiast)
#    utilised some Makefile, then the subdirectories are searched depending on
#    where the executable file – the main script – resides, and on the purpose
#    of the subdirectory. Where each subdirectory is search, read below.
#
#  Bahelite tries to intellectually determine, whether the installation is
#    a solid, standalone or it is split across the root filesystem. For that
#    MYDIR is tested to be /usr/local/bin or /usr/bin, and if it appears to be
#    one of them, BAHELITE_SPLIT_INSTALLATION is set. See the code at the bot-
#    tom of this file.
#  This variable prevents search for source subdirectories in MYDIR. In the
#    case when a user might install the main program both ways – with a pack-
#    age manager and locally, then calling the executable from the local in-
#    stallation should not look into system directories, and stay in MYDIR
#    instead. And vice versa, a split installation will not try to find
#    source subdirectories in $PATH, around the executable.
#
#
#                 Possible paths for source subdirectories
#
#                    SOLID INSTALLATION     SPLIT INSTALLATION
#                    (all in MYDIR)         (separated across filesystem)
#
#            LIBDIR¹ ./lib                        /usr/lib/${MYNAME%.*}
#                                           /usr/local/lib/${MYNAME%.*}
#
#        MODULESDIR² ./modules                    /usr/lib/${MYNAME%.*}
#                                           /usr/local/lib/${MYNAME%.*}
#
#    EXAMPLECONFDIR³ ./exampleconf          /usr/share/${MYNAME%.*}/exampleconf
#                                           /usr/local/share/${MYNAME%.*}/exampleconf
#
#    Notes
#    1. Note, that in the OS the “lib” directory is a common one, so a subdi-
#       rectory is created. the files from the lib in the source code go to
#                    <usr prefix>/lib/${MYNAME%.sh},
#           not into <usr prefix>/lib/${MYNAME%.sh}/lib !
#    2. Modules are essentially libraries too. The division on libs and modu-
#       les in the split installation only reflects the way of keeping files
#       in the source code, where libraries may be third-party and better to
#       be kept separately because of their licence or the ease of updating
#       them, while modules are just parts of the main script separated into
#       their own physical files. If the main script would be distributed
#       as is, merging modules into libs would require a post-unpack hook
#       in the archive or a post-clone hook in the repository, what isn’t
#       conceivable.
#    3. EXAMPLECONFDIR can be any extra directory, e.g. RESDIR or MY_SPECIAL_
#       DATA_DIR.
#    4. Plural forms are possible:
#         - for the solid type of installation both “lib” and “libs” are accep-
#           table, as well as “module and modules”, “exampleconf” and “example-
#           confs”;
#         - for the split type of installation only the extra files may have
#           plural forms (the common “lib” directory belongs to OS).
#       The provided alias functions: set_libdir(), set_modulesdir() etc. set
#       variables in their specific form: LIBDIR, MODULESDIR (not LIBSDIR,
#       MODULEDIR), but you may call set_source_dir() with the variables named
#       to your taste, the underlying function __set_source_dir() will recog-
#       nise both lib/libs and module/modules and will direct it properly
#       in the case of split installation.
#    5. The author doesn’t believe, that somebody would use Bahelite for essen-
#       tial system software, hence the basic directories like /bin and /lib
#       are never searched.


 # Finds paths for the subdirectories of the source code and sets these
#  paths to global variables.
#  $1  – the name of the source subdirectory, e.g. “lib(s)”, “module(s)”,
#        “exampleconf(s)”, “resource(s)” and such. This name in the uppercase
#        will become the global variable that will hold the found path, e.g.
#        “lib” becomes LIBDIR.
# [$2] – the name of the subdirectory to be searched under system directories
#        such as /usr/(local/)lib, /usr/(local/)share etc. By default the
#        name is equal to $MYNAME_NOEXT.
#
__set_source_dir() {
	local  whats_the_dir="${1,,}"   #  LIB → lib
	local  varname="${1^^}DIR"
	local  own_subdir="${2:-$MYNAME_NOEXT}"
	local  dir
	local  possible_paths=()

	if [ -v BAHELITE_SPLIT_INSTALLATION ]; then
		case "$whats_the_dir" in
			lib|module)
			;&
			libs|modules)
				possible_paths+=(
					"$BAHELITE_USRDIR_PREFIX/lib/$own_subdir"
				)
				;;
			*)
				possible_paths+=(
					"$BAHELITE_USRDIR_PREFIX/share/$own_subdir/$whats_the_dir"
					"$BAHELITE_USRDIR_PREFIX/share/$own_subdir/${whats_the_dir}s"
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
			[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
				&& info "Setting $varname to “$dir”"
			declare -gx $varname="$dir"
			break
		}
	done
	[ -v "$varname" ]  || err "Cannot find source directory for $varname."
	return 0
}
#  No export: init stage functions.



 # For the use in __set_source_dir().
#
[[ "$MYDIR" =~ (/usr/bin|/usr/local/bin) ]] && {
	declare -gr BAHELITE_SPLIT_INSTALLATION=t
	declare -gr BAHELITE_USRDIR_PREFIX=${BASH_REMATCH[1]%/bin}
}

return 0