# Should be sourced.

#  bahelite_misc.sh
#  Miscellaneous helper functions.
#  deterenkelt © 2018

# Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	echo 'Must be sourced from bahelite.sh.' >&2
	return 5
}
. "$BAHELITE_DIR/bahelite_messages.sh" || return 5

# Avoid sourcing twice
[ -v BAHELITE_MODULE_MISC_VER ] && return 0
#  Declaring presence of this module for other modules.
BAHELITE_MODULE_MISC_VER='1.7.1'

#  It is *highly* recommended to use “set -eE” in whatever script
#  you’re going to source it from.


 # Set LIBDIR or MODULESDIR
#  [$1] – script’s own subdirectory to search for (when it doesn’t match
#         the script name). Alike to $1 in prepare_cachedir() below.
#
set_libdir()         { set_required_dir LIBDIR         "$@"; }
set_modulesdir()     { set_required_dir MODULESDIR     "$@"; }
set_exampleconfdir() { set_required_dir EXAMPLECONFDIR "$@"; }
#
#  Actually sets LIBDIR and MODULESDIR globally
#   $1  – the variable, that must be set
#  [$2] – a custom subdirectory name, if it doesn’t match with the script
#         own name. Alike to $1 in prepare_cachedir() below.
#
set_required_dir() {
	local varname="$1" whats_the_dir  own_subdir  dir
	whats_the_dir="${varname,,}"
	whats_the_dir=${whats_the_dir%dir}  # LIBDIR → libdir → lib
	[ "${2:-}" ] \
		&& own_subdir="$2" \
		|| own_subdir="${MYNAME%.*}"
	for dir in "/usr/share/$own_subdir/$whats_the_dir" \
	           "/usr/local/share/$own_subdir/$whats_the_dir" \
	           "$MYDIR/$whats_the_dir"
	do
		[ -d "$dir" ] && { declare -g $varname="$dir"; break; }
	done
	[ -v "$varname" ] || err "Cannot find directory for $varname."
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


 # Returns 0 if the argument is a variable, that has a value, that can be
#    treated as positive – yes, Yes, t, True, 1 and so on. Returns 1 if it
#    has a value, that corresponds with a negative value: no, No, f, False,
#    0 etc. Returns an error in case the value is neither.
#  If the second argument -u|--unset-if-not is passed, unsets the variable,
#    if it has a ngeative value and returns with code 0.
#  The purpose is to turn the very existence of a variable into a flag,
#    that can be checked with a simple [ -v flag_variable ] in the code.
#  Arguments:
#     $1 – variable name
#    [$2] – “-u” or “--unset-if-not” to unset a negative variable.
#
is_true() {
	xtrace_off && trap xtrace_on RETURN
	local varname="${1:-}"
	[ -v "$varname" ] || {
		if [ "${FUNCNAME[1]}" = read_rcfile ]; then
			err "Config option “$varname” is requried, but it’s missing."
		else
			err "Cannot check variable “$varname” – it doesn’t exist."
		fi
	}
	[[ "${2:-}" =~ ^(-u|--unset-if-not)$ ]] \
		&& local unset_if_false=t
	declare -n varval="$varname"
	if [[ "$varval" =~ ^(y|Y|[Yy]es|1|t|T|[Tt]rue|[Oo]n|[Ee]nable[d])$ ]]; then
		return 0
	elif [[ "$varval" =~ ^(n|N|[Nn]o|0|f|F|[Ff]alse|[Oo]ff|[Dd]isable[d])$ ]]; then
		[ -v unset_if_false ] && {
			unset $varname
			return 0
		}
		return 1
	else
		if [ -v BAHELITE_MODULE_MESSAGES_VER ]; then
			err "Variable “$varname” must have a boolean value (0/1, on/off, yes/no),
			     but it has “$varval”."
		else
			cat <<-EOF >&2
			Variable “$varname” must have a boolean value (0/1, on/off, yes/no),
			but it has “$varval”.
			EOF
		fi
	fi
	return 0
}


 # Dumps values of variables to stdout and to the log
#  $1..n – variable names
#
dumpvar() {
	xtrace_off && trap xtrace_on RETURN
	local var
	for var in "$@"; do
		msg "$(declare -p $var)"
	done
	return 0
}


 # These two functions are handy to temporarily export bahelite
#  functions into environment, so that when parallel, for example,
#  when it runs a bash function, would pass Bahelite functions
#  and variables to it.
#
bahelite_export() {
	export  __g  __b  __s
	export -f  info  warn  err  msg  strip_colours  \
	           xtrace_off  xtrace_on  milinc  mildec
	return 0
}
bahelite_unexport() {
	export -n  __g  __b  __s
	export -nf  info  warn  err  msg  strip_colours  \
	            xtrace_off  xtrace_on  milinc  mildec
}


 # Checks, that a directory exists and has R/W permissions.
#  $1 – path to the predefined directory.
#  $2 – the purpose like “Config” or “Logging”. It will be used in the
#       error message.
#
bahelite_check_directory() {
	local dir="${1:-}" purpose="${2:-}"
	if [ -d "$dir" ]; then
		[ -r "$dir" ] \
			|| err "$purpose directory “$dir” isn’t readable."
		[ -w "$dir" ] \
			|| err "$purpose directory “$dir” isn’t writeable."
	else
		mkdir -p "$dir" || err "Couldn’t create ${purpose,,} directory “$dir”."
	fi
	return 0
}


 # Sets MYRANDOM global variable to a random number either fast or secure way
#  Secure way may take seconds to complete.
#  $1 – an integer number, which will define the range, [0..$1].
#
random-fast()   { random fast   "$@"; }
random-secure() { random secure "$@"; }
#
 # Generic function
#  $1 – mode, either “fast” or “secure”
#  $2 – an integer number, which will define the range, [0..$1].
#
random() {
	declare -g MYRANDOM
	local mode="${1:-}" max_number="${2:-}"

	case "$mode" in
		fast)    random_source='/dev/urandom';;
		secure)  random_source='/dev/random';;
		*)  err 'Random source must be set to either “fast” or “secure”.'
	esac
	[ -r "$random_source" ] \
		|| err "Random source file $random_source is not a readable file."

	[[ "$max_number" =~ ^[0-9]+$ ]] \
		|| err "The max. number is not specified, got “$max_number”."

	 # $RANDOM is too bad to use even when security is not a concern,
	#  because its seed works bad in containers, and 9/10 times returns
	#  the same value, if you call $RANDOM with equal time spans of one hour.
	#
	#  MYRANDOM will be set to a number between 0 and $max_number inclusively.
	#
	MYRANDOM=$(shuf --random-source=$random_source -r -n 1 -i 0-$max_number)
	return 0
}


 # Removes or replaces characters, that are forbidden in Windows™ filenames.
#  $1 – a string, in which the characters have to be replaced.
#  Returns a new string to stdout.
#
remove_windows_unfriendly_chars() {
	local str="${1:-}"
	str=${str//\</\(}
	str=${str//\>/\)}
	str=${str//\:/\.}
	str=${str//\"/\'}
	str=${str//\\/}
	str=${str//\|/}
	str=${str//\?/}
	str=${str//\*/}
	echo "$str"
	return 0
}


 # Allows only one instance of the main script to run.
#
single_process_check() {
	local our_processes        total_processes \
	      our_processes_count  total_processes_count  our_command

	[ ${#ARGS[*]} -eq 0 ]  \
		&& our_command="bash $MYNAME_AS_IN_DOLLARZERO"  \
		|| our_command="bash $MYNAME_AS_IN_DOLLARZERO ${ARGS[@]}"
	our_processes=$(pgrep -u $USER -afx "$our_command" --session 0 --pgroup 0)
	total_processes=$(pgrep -u $USER -afx "$our_command")
	our_processes_count=$(echo "$our_processes" | wc -l)
	total_processes_count=$(echo "$total_processes" | wc -l)
	(( our_processes_count < total_processes_count )) && {
		warn "Processes: our: $our_processes_count, total: $total_processes_count.
		Our processes are:
		$our_processes
		Our and foreign processes are:
		$total_processes"
		err 'Still running.'
	}
	return 0
}


return 0