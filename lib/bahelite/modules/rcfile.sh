#  Should be sourced.

#  rcfile.sh
#  Functions to source an RC file and verify, that its version is compatible.
#  © deterenkelt 2018–2019

#  Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	cat <<-EOF  >&2
	Bahelite error on loading module ${BASH_SOURCE##*/}:
	load the core module (bahelite.sh) first.
	EOF
	return 4
}

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_RCFILE_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_RCFILE_VER='3.2'
bahelite_load_module 'versioning' || return $?
bahelite_load_module 'confdir' || return $?
bahelite_load_module 'misc' || return $?

BAHELITE_ERROR_MESSAGES+=(
	#  set_rcfile_from_args()
	[rc: no such rc file]='“$1”: no such RC file or the file is not readable.'
	[rc: wrong filename for --rc-file]='The argument for --rc-file must be a config file name.
	    Got “$1”.
	    That config must exist and its name must end on “.rc.sh”.'
	[rc: --rc-file needs an arg]='--rc-file needs an argument.'
)


__show_usage_rcfile_module() {
	cat <<-EOF  >&2
	Bahelite module “rcfile” arguments:

	use_defconf
	use_defconfdir
	    Load the module to set path to the source directory DEFCONFDIR.

	use_metaconf
	use_metaconfdir
	    Load the module to set path to the source directory METACONFDIR.


	The options above are semantic equivalents of adding the respective
	modules to BAHELITE_LOAD_MODULES by themselves. Specifying them as
	options just makes the dependency more vivid to one who reads the code.
	EOF
	return 0
}

for arg in "$@"; do

	if [[ "$arg" =~ ^use_defconf(dir|)$ ]]; then
		bahelite_load_module 'defconfdir'  || return $?

	elif [[ "$arg" =~ ^use_metaconf(dir|)$ ]]; then
		bahelite_load_module 'metaconfdir'  || return $?

	elif [ "$arg" = help ]; then
		__show_usage_rcfile_module
		return 0

	else
		__show_usage_rcfile_module
		return 4
	fi
done
unset arg


 # Define the format for the default RC file name
#
#                          Simple (default)    With script name
#
#  default RC file name    rc.sh               $MYNAME_NOEXT.rc.sh
#  custom RC file name     <anything>.rc.sh    $MYNAME_NOEXT<anything>.rc.sh
#
#  Using format with script name makes sense, if more than one main script
#    uses CONFDIR, DEFCONFDIR, METACONFDIR.
#  Custom RC file names are NEVER picked instead of the default, but they
#    are accepted, when specified via command line.
#  Essentially, defining this variable permits to bundle several main scripts,
#    that use the same configuration directories.
#
declare -g RCFILE_REQUIRE_SCRIPT_NAME_IN_RCFILE_NAME

[ -v MY_BUNCH_NAME ]  && RCFILE_REQUIRE_SCRIPT_NAME_IN_RCFILE_NAME=t


 # Expand this array with config variable names to check their value: yes/no,
#    on/off, true/false, 1/0, enabled/disabled etc. and if it wouldn’t be
#    recognised as “positive”, then unset it, essentially turning the very
#    existence of a variable into a boolean flag.
#  Gives an error, if a variable from this list is not set, or its contents
#    cannot be recognised as either positive or negative (when declared,
#    but not set; when decalred and set, but the value is empty or gibbersih).
#
declare -gax RCFILE_BOOLEAN_VARS=()


 # Expand this array to strip a substring at the end of the value in the
#    config file. (Assuming, that the units are placed there for convenience.)
#  Format:  [variable_name]='string_to_strip'
#  Example: RCFILE_STRIPUNIT+=(  [myvar]='%'  )
#
#               Definition                        After processing
#           myvar='5'                         myvar='5'
#           myvar='5%'                        myvar='5'
#           myvar='5 %'                       myvar='5'
#           myvar=( 5 7% )                    myvar=( 5 7 )
#
declare -gAx RCFILE_STRIPUNIT_VARS=()

declare -gAx RCFILE_CHECKVALUE_VARS=()
declare -gAx RCFILE_CHECKVALUE_VARS_DESCS=()

declare -gAx RCFILE_REPLACEVALUE_VARS=()


 # Returns true (0), if the passed string is a valid rcfile name, false (1)
#  otherwise
#  $1  – file name or a path to file (directories will be stripped)
# [$2] – substitute for $MYNAME, if the script name is required in the
#        RC file name, and the file being checked is for another main script.
#        (If the main script, that is currently running, does the check
#        not for its own RC file, but for some other main script’s RC file.)
#
is_a_valid_rcfile_name() {
	local fname="${1##*/}" script_name=${2:-$MYNAME_NOEXT}
	if [ -v RCFILE_REQUIRE_SCRIPT_NAME_IN_RCFILE_NAME ]; then
		#  Here placing $script_name in the pattern would be dangerous
		[ "${fname#$script_name}" = "$fname" ] && return 1
		[[ "${fname#$script_name}" =~ ^[A-Za-z0-9_\.\,\:\;\-]*\.rc\.sh$ ]] \
			&& return 0  \
			|| return 1
	else
		[[ "$fname" =~ ^rc\.sh$  || "$fname" =~ \.rc\.sh$ ]] \
			&& return 0  \
			|| return 1
	fi
}


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
#       argument list and sets the updated list to the global array $NEW_ARGS.
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
#  Changes:
#    $ARGS – will contain $@ without the options, that set a custom RC file.
#
__set_rcfile_from_args() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	declare -gx  RCFILE  ARGS
	(( $# == 0 ))  && return 0

	[ -v BAHELITE_MODULES_ARE_VERBOSE ]  && {
		info "Setting RCFILE from ARGS"
		milinc
	}

	local     i
	local -a  temp_args=( "$@" )
	local -a  args_to_unset=()
	local     arg
	local     nextarg
	local     arg_nopath
	local     nextarg_nopath
	local     number_of_deleted_args=0
	local     rc_fname

	for ((i=0; i<${#temp_args[*]}; i++)); do
		unset -n  arg  nextarg || true  # Sic!
		unset  arg_nopath  nextarg_nopath || true
		declare -n arg="temp_args[$i]"
		arg_nopath=${arg##*/}
		(( i < (${#temp_args[*]}-1) ))  && {
			declare -n nextarg="temp_args[$i+1]"
			nextarg_nopath="${nextarg##*/}"
		}

		[[ "$arg" =~ ^--rc(-|)file$ ]] && {
			if  (( i < (${#temp_args[*]}-1) ));  then
				if  is_a_valid_rcfile_name "$nextarg_nopath";  then
					if  [ -r "$CONFDIR/$nextarg_nopath" ];  then
						RCFILE="$CONFDIR/$nextarg_nopath"
						args_to_unset+=(  $((   i - number_of_deleted_args   ))
						                  $(( i+1 - number_of_deleted_args++ ))  )
						let '++i,  1'
						continue
					else
						ierr 'rc: no such rc file' "$nextarg_nopath"
					fi
				else
					ierr 'rc: wrong filename for --rc-file' "$nextarg_nopath"
				fi
			else
				ierr 'rc: --rc-file needs an argument'
			fi
		}


		if	   [[ "$arg" =~ ^--rc(-|)file=(.+)$ ]]  \
			|| [[ "$arg" =~ ^--rc(-|)file=\'(.+)\'$ ]]  \
			|| [[ "$arg" =~ ^--rc(-|)file=\"(.+)\"$ ]]
		then
			rc_fname="${BASH_REMATCH[2]}"
			rc_fname="${rc_fname##*/}"
			if  is_a_valid_rcfile_name "$rc_fname";  then
				[ -r "$CONFDIR/$rc_fname" ] && {
					RCFILE="$CONFDIR/$rc_fname"
					args_to_unset+=(  $(( i - number_of_deleted_args++ ))  )
					continue
				} ||  ierr 'rc: no such rc file' "$rc_fname"
			else
				ierr 'rc: wrong filename for --rc-file' "$rc_fname"
			fi
		fi


		 # The check on RC file path per se must be the last check,
		#  as cutting the directories also removes “--rcfile=” in the
		#  beginning.
		#
		is_a_valid_rcfile_name "$arg_nopath" && {
			[ -r "$CONFDIR/$arg_nopath" ] && {
				RCFILE="$CONFDIR/$arg_nopath"
				args_to_unset+=(  $(( i - number_of_deleted_args++ ))  )
				continue
			} || ierr 'rc: no such rc file' "$arg_nopath"
		}

	done

	for i in ${args_to_unset[*]}; do
		unset temp_args[$i]
	done

	#  ARGS is identical to ORIG_ARGS here.
	(( ${#temp_args[*]} != ${#ARGS[*]} )) && {
		ARGS=( "${temp_args[@]}" )

		[ -v BAHELITE_MODULES_ARE_VERBOSE ] && {
			info "Setting RCFILE to “$RCFILE”."
			info "Setting new ARGS:"
			milinc
			for ((i=0; i<${#ARGS[@]}; i++)) do
				msg "ARGS[$i] = ${ARGS[i]}"
			done
			mildec
		}

	}

	[ -v BAHELITE_MODULES_ARE_VERBOSE ] && mildec

	return 0
}
#  No export: init stage function.


 # Copies a default configuration file as example into CONFDIR.
#  If the configuration file in DEFCONFDIR will not be newer than an existing
#  example file, the example file won’t be replaced.
#  [$1] – name of a file in DEFCONFDIR. If omitted, then the first file
#         in alphabetic order, that would have a valid name, will be placed.
#  [$2] – script name. If not set, MYNAME_NOEXT is used.
#         Requires $1 to be set (pass an empty string in place of $1
#         to allow automatic search).
#
place_examplerc() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local defconf="${1:-}"  script_name="${2:-$MYNAME_NOEXT}"
	local exampleconf="$CONFDIR/example.$script_name.rc.sh"
	[ -v BAHELITE_MODULES_ARE_VERBOSE ] && local verbosecp='--verbose'

	[ -v DEFCONFDIR  -a  -v CONFDIR ]  \
		|| err "DEFCONFDIR and CONFDIR must be set."

	if [ -f "$DEFCONFDIR/$defconf"  -a  -r "$DEFCONFDIR/$defconf" ]; then
		cp --update ${verbosecp:-} "$DEFCONFDIR/$defconf"  "$exampleconf"

	else
		defconf=$(ls -1 "$DEFCONFDIR" | head -n1)
		if [ -f "$DEFCONFDIR/$defconf"  -a  -r "$DEFCONFDIR/$defconf" ]; then
			cp --update ${verbosecp:-} "$DEFCONFDIR/$defconf"  "$exampleconf"
		else
			[ -v BAHELITE_MODULES_ARE_VERBOSE ] \
				&& warn "rc: ${FUNCANME[0]}: There is no config in $DEFCONFDIR
				         to place as $exampleconf"
        fi

    fi

	return 0
}
#  No export: init stage function.


 # Source meta and then default configuration from the installation directory
#  Unlike with directory that hold *user’s* configuration files, here all
#  appropriate by name files, are sourced. (Assuming that the default and meta
#  configuration files are split for convenience and modularisation purposes.)
#
__read_metaconfdir() {  __read_metaconfdir_or_defconfdir  meta;  }
__read_defconfdir()  {  __read_metaconfdir_or_defconfdir  def;   }
__read_metaconfdir_or_defconfdir() {
	#  Internal! No xtrace_off/on needed!
	local  meta_or_def="$1"
	local  dir

	[ -v BAHELITE_MODULES_ARE_VERBOSE ]  && {
		info "Reading ${meta_or_def^^}CONFDIR:"
		milinc
	}

	case "$meta_or_def" in
		meta)
			[ -v METACONFDIR ] || err 'METACONFDIR must be set!'
			declare -n dir=METACONFDIR
			;;

		def)
			[ -v DEFCONFDIR ] || err 'DEFCONFDIR must be set!'
			declare -n dir=DEFCONFDIR
			;;
	esac

	local conf_files=() conf_file  conf_file_path

	 # “|| true” is needed to avoid ls quitting with an error, if there is
	#  just no configuration files in either defconf or in metaconf.
	#
	if [ -v RCFILE_REQUIRE_SCRIPT_NAME_IN_RCFILE_NAME ]; then
		[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
			&& info "Loading by glob pattern “$RCFILE_SCRIPTNAME\.*rc\.sh”."
		conf_files=(
			$(set +f;  \
			  ls -1 "$dir/$RCFILE_SCRIPTNAME".*rc.sh  2>/dev/null || true)
		)
	else
		[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
			&& info "Loading by glob pattern “*rc.sh”."
		conf_files=(
			$(set +f;  \
			  ls -1 "$dir/"*rc.sh  2>/dev/null || true)
		)
	fi

	[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
		&& info "Found ${#conf_files[@]} config files."

	for conf_file in "${conf_files[@]}"; do
		conf_file_path="$conf_file"
		is_a_valid_rcfile_name "$conf_file" "$RCFILE_SCRIPTNAME" || {
			[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
				&& warn "skipping rcfile because of inappropriate file name:
				         $conf_file_path"
			continue
		}
		if [ -f "$conf_file_path"  -a  -r "$conf_file_path" ]; then
			[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
				&& info "sourcing  $conf_file_path"
			. "$conf_file_path"  \
				|| err "Error on sourcing ${meta_or_def}conf file:
				        $conf_file_path"
		else
			[ -v BAHELITE_MODULES_ARE_VERBOSE ] \
				&& warn "${meta_or_def}conf path is not a readable file:
				         $conf_file_path"
		fi
	done

	[ -v BAHELITE_MODULES_ARE_VERBOSE ]  && {
		mildec
	}

	return 0
}
#  No export: read_rcfile’s subroutine, which is an init stage function.


 # Search CONFDIR for the default rcfile names
#  Technically this function should be a native part of __read_confdir(),
#  but it has to be set separately for the ease of dealing with the multiple
#  conditions that complicate the search.
#
__set_rcfile_from_confdir() {
	#  Internal! No xtrace_off/on needed!
	declare -gx RCFILE
	local rc_path

	#  If already set from the command line, then RCFILE already points
	#  to a valid file, there’s no need to search.
	if [ -v RCFILE ]; then
		[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
			&& info "RCFILE is already set via command line."
		return 0
	else
		[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
			&& info "No custom RCFILE was set via command line.
			         Now searching CONFDIR for default names…"
	fi

	[ -v CONFDIR ] || err 'CONFDIR must be set!'

	rc_path="$CONFDIR/$RCFILE_SCRIPTNAME.rc.sh"
	[ -f "$rc_path"  -a  -r "$rc_path" ] && {
		RCFILE="$rc_path"
		return 0
	}

	#  Cannot search for the other file names, assuming, that there is no
	#  custom $MYNAME_NOEXT.rc.sh  or that the rest are custom names configs
	#  that should be specified via command line
	[ -v RCFILE_REQUIRE_SCRIPT_NAME_IN_RCFILE_NAME ] && return 0

	#  If simple RC file name rc.sh is allowed
	rc_path="$CONFDIR/rc.sh"
	[ -f "$rc_path"  -a  -r "$rc_path" ] && {
		RCFILE="$rc_path"
		return 0
	}

	#  If there is not even simple rc.sh, assuming there’s no custom rc.sh.
	return 0
}
#  No export: read_rcfile’s subroutine, which is an init stage function.


 # Source user’s configuration file from CONFDIR.
#  Unlike with metaconf and defconf, that source *every* appropriate by name
#    file, here *only one* file with the *default name* is sourced.
#  Sourcing a custom config file happens only when its filename was specified
#    via the command line
#
__read_confdir() {
	#  Internal! No xtrace_off/on needed!
	[ -v BAHELITE_MODULES_ARE_VERBOSE ]  && {
		info "Searching CONFDIR for an rcfile"
		milinc
	}
	__set_rcfile_from_confdir

	if [ -v RCFILE ]; then
		[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
			&& info "Sourcing RCFILE “${RCFILE##*/}”."
		. "$RCFILE" || err "Error while sourcing RCFILE
		                    $RCFILE"
	else
		[ -v BAHELITE_MODULES_ARE_VERBOSE ] \
			&& info "No default RC file found in CONFDIR."
	fi

	[ -v BAHELITE_MODULES_ARE_VERBOSE ] && mildec
	return 0
}


__postprocess_rc_variables() {
	#  Internal! No xtrace_off/on needed!
	local varname  varval  varval_pattern  repl  i

	[ -v BAHELITE_MODULES_ARE_VERBOSE ]  && {
		info "Checking values of the RC variables."
		milinc
	}

	for varname in "${!RCFILE_CHECKVALUE_VARS[@]}"; do
		if [ -v "$varname" ]; then
			declare -n varval="$varname"
			varval_pattern="${RCFILE_CHECKVALUE_VARS[$varname]}"
			case "$varval_pattern" in
				bool)
					is_bool $varname
					;;

				int)
					is_integer $varname
					;;

				int_in_range\ *)
					is_integer_in_range $varname ${varval_pattern#* }
					;;

				int_with_unit\ *)
					is_integer_with_unit $varname ${varval_pattern#* }
					;;

				int_with_unit_or_without_it\ *)
					is_integer_with_unit_or_without_it $varname ${varval_pattern#* }
					;;

				int_in_range_with_unit\ *)
					is_integer_in_range_with_unit $varname ${varval_pattern#* }
					;;

				int_in_range_with_unit_or_without_it\ *)
					is_integer_in_range_with_unit_or_without_it $varname ${varval_pattern#* }
					;;

				float)
					is_float "$varname"
					;;

				float_in_range\ *)
					is_float_in_range $varname ${varval_pattern#* }
					;;

				float_with_unit\ *)
					is_float_with_unit $varname ${varval_pattern#* }
					;;

				float_with_unit_or_without_it\ *)
					is_float_with_unit_or_without_it $varname ${varval_pattern#* }
					;;

				float_in_range_with_unit\ *)
					is_float_in_range_with_unit $varname ${varval_pattern#* }
					;;

				float_in_range_with_unit_or_without_it\ *)
					is_float_in_range_with_unit_or_without_it $varname ${varval_pattern#* }
					;;

				filepath)
					is_a_readable_file $varname
					;;

				dirpath)
					is_a_readable_dir $varname
					;;

				*)
					[[ "$varval" =~ $varval_pattern ]] || {
						if [ -v RCFILE_CHECKVALUE_VARS_DESCS[$varname]  ]; then
							err "Error in the configuration file:
							     ${RCFILE_CHECKVALUE_VARS_DESCS[$varname]}"
						else
							err "Error in the configuration file:
							     $varname is set to an invalid value “$varval”."
						fi
					}
					;;
			esac

			[ -v RCFILE_REPLACEVALUE_VARS[$varname]  ] && {
				repl="${RCFILE_REPLACEVALUE_VARS[$varname]}"
				for ((i=1; i<${#BASH_REMATCH[*]}; i++)); do
					repl="${repl//\\$i/${BASH_REMATCH[i]:-}}"
				done
				varval="$repl"
			}
		else
			[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
				&& warn "Skipping variable $varname: it isn’t set."
		fi
	done

	[ -v BAHELITE_MODULES_ARE_VERBOSE ]  && mildec
	return 0
}
#  No export: read_rcfile’s subroutine, which is an init stage function.


 # Reads an RC file and verifies, that it has a compatible version.
#  If version is lower, than minimum compatible version, throws an error.
#  [$1] – script name to be used, if RCFILE_REQUIRE_SCRIPT_NAME_IN_RCFILE_NAME
#         is set. If not set, equals to MYNAME_NOEXT.
#
read_rcfile() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	#  To be used in all underlying functions.
	declare -g RCFILE_SCRIPTNAME
	# local  rcfile  varname  old_vars  new_vars  missing_variable_list=()

	[[ "${1:-}" =~ ^[A-Za-z0-9_\.\,\;\:-]+$ ]]  \
		&& RCFILE_SCRIPTNAME="$1"  \
		|| RCFILE_SCRIPTNAME="$MYNAME_NOEXT"

	if [ -v METACONFDIR ]; then
		__read_metaconfdir
	else
		[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
			&& info "METACONFDIR is not set – not reading meta RC files."
	fi

	if [ -v DEFCONFDIR ]; then
		__read_defconfdir
	else
		[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
			&& info "DEFCONFDIR is not set – not reading default RC files."
	fi

	__set_rcfile_from_args "${ARGS[@]}"
	__read_confdir
	__postprocess_rc_variables

	return 0
}
#  No export: init stage function.


BAHELITE_POSTLOAD_JOBS+=( "read_rcfile:after=prepare_confdir,prepare_defconfdir,prepare_metaconfdir" )


return 0