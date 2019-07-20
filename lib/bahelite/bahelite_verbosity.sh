#  Should be sourced.

#  bahelite_verbosity.sh
#  Facilities to control the verbosity level and presets for the console output.
#  © deterenkelt 2019

#  Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	echo "Bahelite error on loading module ${BASH_SOURCE##*/}:"
	echo "load the core module (bahelite.sh) first." >&2
	return 4
}

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_VERBOSITY_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_VERBOSITY_VER='1.1.1'



 # Removes spacing characters: “-”, “_” and “ ” from VERBOSITY_LEVEL
#
bahelite_sanitise_verbosity_level() {
	declare -g VERBOSITY_LEVEL
	if [[ "$VERBOSITY_LEVEL" =~ ^([0-9]{2})[\ _-]?([0-9]{2})[\ _-]?([0-9]{2}) ]]; then
		#  All six numbers? Just remove spacing.
		VERBOSITY_LEVEL="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}"

	elif [[ "$VERBOSITY_LEVEL" =~ ^([0-9])[\ _-]?([0-9])[\ _-]?([0-9]) ]]; then
		#  Short form of three numbers? Remove spacing, add zeroes
		#  for user-level verbosity.
		VERBOSITY_LEVEL="${BASH_REMATCH[1]}0${BASH_REMATCH[2]}0${BASH_REMATCH[3]}0"

	else
		redmsg "Incorrect value for VERBOSITY_LEVEL: “$VERBOSITY_LEVEL”.
		        Should be a string of six numbers, optionally divided by either
		        a space, a hyphen or an underscore, e.g. 303030 or 30-10-00."
		err "VERBOSITY_LEVEL must be a string of six numbers."
	fi
	return 0
}
#  No export: init stage function.


 # Verifies, that VERBOSITY_LEVEL is a correct string.
#  To be used in runtime calls to get_bahelite/user_verbosity().
#
bahelite_verify_verbosity_level() {
	#  In the future more format may appear, e.g. as an associative array
	#  or as a string with spaces like “30 30 30”.
	[[ "$VERBOSITY_LEVEL" =~ ^[0-9]{6}$ ]] || {
		redmsg "Incorrect value for VERBOSITY_LEVEL: “$VERBOSITY_LEVEL”.
		        Should be a string of six numbers, optionally divided by either
		        a space, a hyphen or an underscore."
		err "VERBOSITY_LEVEL must be a string of six numbers."
	}
	return 0
}
export -f  bahelite_verify_verbosity_level


 # Extracts output (log/console/desktop) verbosity level from VERBOSITY_LEVEL.
#
#  Returns the first number of the output verbosity number,
#  e.g. 123456 for requested output “log” will return “1”
get_bahelite_verbosity()  { __get_verbosity "$1" bahelite; }
#
#  Returns the second digit of the output verbosity number,
#  e.g. 123456 for requested output “log” will return “2”
get_user_verbosity()      { __get_verbosity "$1" user; }
#
#  Returns both digits of the output verbosity number,
#  e.g. 123456 for requested output “log” will return “10”
get_overall_verbosity()   { __get_verbosity "$1" overall; }
#
#
__get_verbosity() {
	local output="$1" mode="$2"
	bahelite_verify_verbosity_level
	case "$output" in
		log|logging)
			case "$mode" in
				'bahelite')
					echo "${VERBOSITY_LEVEL:0:1}"
					;;
				'user')
					echo "${VERBOSITY_LEVEL:1:1}"
					;;
				'overall')
					echo "${VERBOSITY_LEVEL:0:2}"
					;;
			esac
			;;

		console)
			case "$mode" in
				'bahelite')
					echo "${VERBOSITY_LEVEL:2:1}"
					;;
				'user')
					echo "${VERBOSITY_LEVEL:3:1}"
					;;
				'overall')
					echo "${VERBOSITY_LEVEL:2:2}"
					;;
			esac
			;;

		desktop)
			case "$mode" in
				'bahelite')
					echo "${VERBOSITY_LEVEL:4:1}"
					;;
				'user')
					echo "${VERBOSITY_LEVEL:5:1}"
					;;
				'overall')
					echo "${VERBOSITY_LEVEL:4:2}"
					;;
			esac
			;;
		*)
			err "Unknown verbosity output: “$output”.
			     Must be one of: log, console, desktop."
			;;
	esac
	return 0
}
export -f  __get_verbosity             \
               get_bahelite_verbosity  \
               get_user_verbosity      \
               get_overall_verbosity


print_verbosity_level() {
	info "VERBOSITY_LEVEL = $VERBOSITY_LEVEL"
	(( $(get_bahelite_verbosity console) < 5 ))  \
		&& msg "To show the debugging output, raise the verbosity to xx50xx or xx60xx."
	return 0
}


 # Setting VERBOSITY_LEVEL to a default value, if not set, then converting
#  the whatever value it has, to the full form.
#
[ -v VERBOSITY_LEVEL ]  \
	|| declare -gx VERBOSITY_LEVEL='333'
bahelite_sanitise_verbosity_level


                        #  Stream control  #

 # Remembering the original FD paths. They are needed to send info, warn etc.
#  messages from subshells properly.
#
if (( BASH_SUBSHELL == 0 )); then
	declare -gx STDIN_ORIG_FD_PATH="/proc/$$/fd/0"
	declare -gx STDOUT_ORIG_FD_PATH="/proc/$$/fd/1"
	declare -gx STDERR_ORIG_FD_PATH="/proc/$$/fd/2"
else
	[ -v STDIN_ORIG_FD_PATH ]  \
		|| declare -gx STDIN_ORIG_FD_PATH="/proc/$$/fd/0"
	[ -v STDOUT_ORIG_FD_PATH ]  \
		|| declare -gx STDOUT_ORIG_FD_PATH="/proc/$$/fd/1"
	[ -v STDERR_ORIG_FD_PATH ]  \
		|| declare -gx STDERR_ORIG_FD_PATH="/proc/$$/fd/2"
fi


 # Setting initial verbosity according to $VERBOSITY_LEVEL.
#
#  Saving the original destinations of console stdout and stderr,
#  so that they may be used to bypass writing some temporary information
#  like a progressbar to the log file, and also for the logging module
#  to have these in case console verbosity would redirect stdout and stderr
#  to /dev/null.
#
exec {STDOUT_ORIG_FD}>&1
exec {STDERR_ORIG_FD}>&2
case "$(get_bahelite_verbosity  'console')" in
	0)	exec 1>/dev/null
		#
		#  If the logging module would need to log stdout, it would need
		#  to know, that it must grab not FD 1, but FD $STDOUT_ORIG_FD.
		#  Same for stderr.
		#
		BAHELITE_CONSOLE_VERBOSITY_SENT_STDOUT_TO_DEVNULL=t
		exec 2>/dev/null
		BAHELITE_CONSOLE_VERBOSITY_SENT_STDERR_TO_DEVNULL=t
		;;

	1)	exec 1>/dev/null
		BAHELITE_CONSOLE_VERBOSITY_SENT_STDOUT_TO_DEVNULL=t
		;;

	4|5|6|7|8|9)
		BAHELITE_XTRACE_ALLOWED=t
		;;&

	5|6|7|8|9)
		BAHELITE_MODULES_ARE_VERBOSE=t
		BAHELITE_DONT_CLEAR_TMPDIR=t
		;;
esac

return 0