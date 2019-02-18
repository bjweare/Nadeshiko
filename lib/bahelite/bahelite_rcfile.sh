# Should be sourced.

#  bahelite_rcfile.sh
#  Functions to source an RC file and verify, that its version is compatible.

# Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	echo 'Must be sourced from bahelite.sh.' >&2
	return 5
}
. "$BAHELITE_DIR/bahelite_messages.sh" || return 5
. "$BAHELITE_DIR/bahelite_versioning.sh" || return 5
. "$BAHELITE_DIR/bahelite_directories.sh" || return 5

# Avoid sourcing twice
[ -v BAHELITE_MODULE_RCFILE_VER ] && return 0
#  Declaring presence of this module for other modules.
BAHELITE_MODULE_RCFILE_VER='1.4.6'

BAHELITE_ERROR_MESSAGES+=(
	#  set_rcfile_from_args()
	[rc: no such rc file]='“$1”: no such RC file or the file is not readable.'
	[rc: wrong filename for --rc-file]='The argument for --rc-file must be a config file name.
	    Got “$1”.
	    That config must exist and its name must end on “.rc.sh”.'
	[rc: --rc-file needs an arg]='--rc-file needs an argument.'
)

 # Expand this array with variable names in your script to check
#  their value (yes/no, 0/1, enabled/disabled…), give an error,
#  if there’s no such variable and unset the variables having negative
#  value (so that they could be later checked with [ -v varname ]).
#
RCFILE_BOOLEAN_VARS=()


 # Pass the main script’s positional parameters to this function
#    to set a custom RC file (and read it with read_rc_file()) before
#    processing the arguments the usual way.
#  The problem, which this function solves is that reading command line
#    arguments in the main script should happen *after* reading the RC file –
#    as first you read the defaults from the RC, then you override them with
#    command line arguments. However, setting a custom RC file at the same
#    time the arguments are processed, is troublesome:
#      - the option that sets a custom RC file has to be put in front
#        in order to be read first;
#      - then it turns out, that reading the rc file must happen at the time
#        of processing command line arguments – in case there would be
#        a custom RC.
#    This is inconvenient and makes the code too entangled.
#  Instead of processing all arguments together this function does it
#    another way.
#    1. It reads the argument list before it is read by the main script’s
#       own functions.
#    2. It sets RCFILE to a custom RC file, if such an option is found.
#    3. It removes the option, that was setting a custom rc file, from the
#       argument list and sets the updated list to the global array $args.
#  The options for alternating $RCFILE, that would be detected
#    and removed, are:
#    - a string that is an existing file name in $CONFDIR, ending with
#      “.rc.sh”, e.g. “myconfig.rc.sh” (i.e. the value as is, wihtout a key);
#    - “--rcfile” or “--rc-file” and the string following it. The string
#      must be an existing file name in $CONFDIR and end with “.rc.sh”.
#    - as the variant above, but the key is separated from the value
#      with an “=” sign instead of a space.
#  Arguments:
#    $1..n – positional arguments for the main script, i.e. "$@".
#  Sets:
#    $args – the new array containing $@ without the options, that set
#            a custom RC file.
#
set_rcfile_from_args() {
	declare -g  RCFILE  args
	[ $# -eq 0 ] &&	{ args=(); return 0; }

	local  temp_args=( "$@" )  i  args_to_unset=()  \
	       arg  next_arg  \
	       number_of_deleted_args=0  fname_pattern='[A-Za-z0-9_\.\,\:\;\-]+\.rc\.sh'

	for ((i=0; i<${#temp_args[*]}; i++)); do
		unset -n  arg  next_arg  ||:
		declare -n arg="temp_args[$i]"
		(( i < (${#temp_args[*]}-1) )) \
			&& declare -n next_arg="temp_args[$i+1]"

		[[ "$arg" =~ ^$fname_pattern$ ]] && {
			[ -r "$CONFDIR/$arg" ] && {
				RCFILE="$CONFDIR/$arg"
				args_to_unset+=(  $(( i - number_of_deleted_args++ ))  )
				continue
			} || ierr 'rc: no such rc file' "$arg"
		}

		[[ "$arg" =~ ^--rc(-|)file$ ]] && {
			if  (( i < (${#temp_args[*]}-1) ));  then
				if  [[ "$next_arg" =~ ^$fname_pattern$ ]];  then
					if  [ -r "$CONFDIR/$next_arg" ];  then
						RCFILE="$CONFDIR/$next_arg"
						args_to_unset+=(  $((   i - number_of_deleted_args   ))
						                  $(( i+1 - number_of_deleted_args++ ))  )
						let ++i
						continue
					else
						ierr 'rc: no such rc file' "$next_arg"
					fi
				else
					ierr 'rc: wrong filename for --rc-file' "$next_arg"
				fi
			else
				ierr 'rc: --rc-file needs an arg'
			fi
		}

		[[ "$arg" =~ ^--rc(-|)file= ]] && {

			if  [[ "$arg" =~ ^--rc(-|)file=($fname_pattern)$ ]];  then
				[ -r "$CONFDIR/${BASH_REMATCH[2]}" ] && {
					RCFILE="$CONFDIR/${BASH_REMATCH[2]}"
					args_to_unset+=(  $(( i - number_of_deleted_args++ ))  )
					continue
				} ||  ierr 'rc: no such rc file' "${BASH_REMATCH[2]}"

			elif  [[ "$arg" =~ ^--rc(-|)file=\"($fname_pattern)\"$ ]];  then
				[ -r "$CONFDIR/${BASH_REMATCH[2]}" ] && {
					RCFILE="$CONFDIR/${BASH_REMATCH[2]}"
					args_to_unset+=(  $(( i - number_of_deleted_args++ ))  )
					continue
				} ||  ierr 'rc: no such rc file' "${BASH_REMATCH[2]}"

			elif  [[ "$arg" =~ ^--rc(-|)file=\'($fname_pattern)\'$ ]];  then
				[ -r "$CONFDIR/${BASH_REMATCH[2]}" ] && {
					RCFILE="$CONFDIR/${BASH_REMATCH[2]}"
					args_to_unset+=(  $(( i - number_of_deleted_args++ ))  )
					continue
				} ||  ierr 'rc: no such rc file' "${BASH_REMATCH[2]}"

			else
				local arg_to_display
				arg_to_display=${arg#--rc-file}
				arg_to_display=${arg_to_display#--rcfile}
				ierr 'rc: wrong filename for --rc-file' "$arg_to_display"
			fi

		}
	done
	for i in ${args_to_unset[*]}; do
		unset temp_args[$i]
	done
	args=( "${temp_args[@]}" )
	return 0
}


 # Copies example RC file from the installation files into user’s CONFDIR.
#  Updates an old example RC file, if the file in the installation is newer.
#  If there is no RC file in CONFDIR, puts a copy of example RC in its place.
#  [$1] – name of the example rc file (only the unique part). If not set,
#         equals to "${MYNAME%.*}".
#            It makes sense to pass this parameter, if you have a bundle of
#         scripts each with its own config, and you have one “mother” script,
#         that calls another. If the mother script reads other script’s RC file
#        (or just verifies, that it does exist), this will trigger an error –
#         at least until somebody would figure out to launch that inner script
#         by itself. Thus, if you’re going to operate with another script RC
#         file, you should prepare its RC files beforehand with this function
#         and pass the name of that script as an argument.
#  If the argument is not set or is equal to “${MYFILE%.*}”,
#  then RCFILE and EXAMPLE_RCFILE are set.
#
place_rc_and_examplerc() {
	declare -g  RCFILE  EXAMPLE_RCFILE
	local config_name="${MYNAME%.*}"
	[ "${1:-}" ] && config_name="$1"
	local rc_path="$CONFDIR/$config_name.rc.sh"
	local installed_examplerc_path="$EXAMPLECONFDIR/example.$config_name.rc.sh"
	local local_examplerc_path="$CONFDIR/example.$config_name.rc.sh"

	if [ -v EXAMPLECONFDIR ]; then
		#  Copy or update config example.
		if [ -r "$installed_examplerc_path" ]; then
			[ "$installed_examplerc_path" -nt "$local_examplerc_path" ] \
				&&  cp "$installed_examplerc_path" "$local_examplerc_path"
		else
			warn "Example RC file doesn’t exist in the installation
			      $installed_examplerc_path
			      Check that “set_exampleconfdir” is called prior to calling
			      “prepare_confdir”, and the latter – before this function."
			err "Example RC file doesn’t exist."
		fi
		[ ! -r "$rc_path" ] && {
			info "RC file ($rc_path) doesn’t exist, copying example RC file:
			      $local_examplerc_path"
			cp "$local_examplerc_path" "$rc_path" \
				|| err "Couldn’t create RC file!"
		}
		#  Setting global values only when working with script’s own
		#  RC and example RC files.
		[ "$config_name" = "${MYNAME%.*}" ] && {
			RCFILE="$rc_path"
			EXAMPLE_RCFILE="$local_examplerc_path"
		}
	else
		err "EXAMPLECONFDIR is not set."
	fi
	return 0
}


 # Reads an RC file and verifies, that it has a compatible version.
#  If version is lower, than minimum compatible version, throws an error.
#   $1 – the minimal compatible version for the RC file.
#  [$2] – path to RC file.
#  [$3] – example RC file, that should silently be copied and used,
#         if there would be no RC file (it’s the first time program starts).
#
read_rcfile() {
	xtrace_off && trap xtrace_on RETURN
	local  rcfile_min_ver="$1"  rcfile  example_rcfile  which_is_newer \
	       rcfile_ver  varname  old_vars  new_vars  missing_variable_list=() \
	       plural_s  verb

	if [ "${2:-}" ]; then
		rcfile="$2"
	else
		[ -v RCFILE ] || err 'No RC file provided and RCFILE is not set.
		                      Did you forget to run prepare_confdir?'
		rcfile="$RCFILE"
	fi

	if [ "${3:-}" ]; then
		example_rcfile="$3"
	else
		[ -v EXAMPLE_RCFILE ] \
			|| err "No example RC file provided and EXAMPLE_RCFILE is not set.
		            Did you forget to run place_rc_and_examplerc?"
		example_rcfile="$EXAMPLE_RCFILE"
	fi
	#  This allows to keep user RC files short.
	#  Full settings are picked from the example RC, and user’s RC
	#  just overrides them.
	. "$example_rcfile"

	if [ -r "$rcfile" ]; then
		#  Verifying RC file version
		rcfile_ver=$(
			sed -rn "1 s/\s*#\s*(${rcfile##*/}|${MYNAME%.sh}.rc.sh)\s+v([0-9\.]+)\s*$/\2/p" \
			        "$rcfile"
		)
		which_is_newer=$(compare_versions "$rcfile_ver" "$rcfile_min_ver")
		[ "$which_is_newer" = "$rcfile_min_ver" ] && {
			warn "RC file format changed!
			      Current RC version: $rcfile_ver
			      Minimum compatible version: $rcfile_min_ver"
			warn-ns 'Please COPY and EDIT the new RC file!'
			exit 7
		}
		. "$rcfile"
	else
		err "RC file doesn’t exist:
		     $rcfile"
	fi

	#  Unsetting variables with a negative value
	for varname in "${RCFILE_BOOLEAN_VARS[@]}"; do
		is_true $varname --unset-if-not
	done
	return 0
}


return 0