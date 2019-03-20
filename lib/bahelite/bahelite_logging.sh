# Should be sourced.

#  bahelite_logging.sh
#  Organises logging and maintains logs in a separate folder.
#  © deterenkelt 2018–2019

#  Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	echo "Bahelite error on loading module ${BASH_SOURCE##*/}:"
	echo "load the core module (bahelite.sh) first." >&2
	return 4
}

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_LOGGING_VER ] && return 0
bahelite_load_module 'directories' || return $?
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_LOGGING_VER='1.6'
BAHELITE_INTERNALLY_REQUIRED_UTILS+=(
#	date   #  (coreutils) to add date to $LOGPATH file name and to the log itself.
#	ls     #  (coreutils)
	xargs  #  (findutils)
	pkill  #  (procps) to find and kill the logging tee nicely, so it wouldn’t
	       #           hang.
)



if [ -v LOGGING_MAX_LOGFILES ]; then
	[[ "$LOGGING_MAX_LOGFILES" =~ ^[0-9]{1,4}$ ]] \
		|| err "LOGGING_MAX_LOGFILES should be a number,
		        but it was set to “$LOGGING_MAX_LOGFILES”."
else
	declare -gx LOGGING_MAX_LOGFILES=5
fi


 # Organises logging for the main script
#  Determines LOGDIR and creates file LOGNAME in LOGPATH, then writes initial
#  records to it. LOGPATH and LOGDIR might be specified through environment,
#  see below. Logging obeys verbosity leves, see more about them
#  in bahelite_messages.sh.
#
#  Enabling extglob temporarily or the “source” command will catch an error
#  while trying to source the function code.
bahelite_extglob_on
start_logging() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	[ "$(get_bahelite_verbosity  log)" == '0' ] && return 0
	declare -gx  LOGPATH  LOGDIR  LOGNAME  \
	             BAHELITE_LOGGING_STARTED  BAHELITE_LOGGING_USES_TEE
	local arg  overwrite_logpath=t
	#  Priority of directories to be used as LOGDIR
	#  LOGPATH set from the environment.              LOGPATH = LOGPATH
	#  │                                               LOGDIR = ${LOGPATH%/*}
	#  └ if not set:
	#    LOGDIR set from the environment.              LOGDIR = $LOGDIR
	#    └ if not set:
	#      CACHEDIR set by prepare_cachedir().         LOGDIR = $CACHEDIR/logs
	#      └ if not set:
	#        MYDIR.                                    LOGDIR = $MYDIR/logs 
	#        └ if can’t write to it:
	#          TMPDIR.                                 LOGDIR = $TMPDIR/logs
	#          (In this case you may also want to set
	#           BAHELITE_DONT_CLEAR_TMPDIR.)
	if [ -v LOGPATH ]; then
		touch "$LOGPATH" || {
			redmsg "Cannot write to LOGPATH specified in the environment:
			        $LOGPATH"
			err "LOGPATH is not writeable."
		}
		LOGDIR=${LOGPATH%/*}
		LOGNAME=${LOGPATH##*/}
		bahelite_check_directory "$LOGDIR"  'Logging'
		unset overwrite_logpath

	elif [ -v LOGDIR ]; then
		#  If LOGDIR is not a writeable directory, triggers an error.
		bahelite_check_directory "$LOGDIR"  'Logging'

	else
		LOGDIR="${CACHEDIR:-$MYDIR}/logs"
		[ -d "$LOGDIR"  -a  -w "$LOGDIR" ] || {
			mkdir "$LOGDIR" &>/dev/null || {
				warn "Cannot create “$LOGDIR”. Will write to “$TMPDIR/logs”."
				LOGDIR="$TMPDIR/logs"
				mkdir "$LOGDIR"
			}
		}
	fi

	[ -v LOGPATH ] || {
		LOGNAME="${MYNAME%.*}_$(date +%Y-%m-%d_%H:%M:%S).log"
		LOGPATH="$LOGDIR/$LOGNAME"
	}
	#  Removing old logs, keeping maximum of $LOGGING_MAX_LOGFILES
	#  of recent logs.
	pushd "$LOGDIR" >/dev/null
	#  Deleting leftover variable dump.
	rm -f variables

	bahelite_noglob_off
	bahelite_extglob_on
	(ls -r "${MYNAME%.*}_"+([_0-9:-]).log 2>/dev/null || true ) \
		| tail -n+$LOGGING_MAX_LOGFILES \
		| xargs rm -v &>/dev/null || true
	(ls -r "${MYNAME%.*}_"+([_0-9:-]).xtrace.log 2>/dev/null || true ) \
		| tail -n+$LOGGING_MAX_LOGFILES \
		| xargs rm -v &>/dev/null || true
	bahelite_extglob_off
	bahelite_noglob_on
	popd >/dev/null
	[ -v overwrite_logpath ]  \
		&& echo -n  >"$LOGPATH"
	echo "${__mi}Log started at $(LC_TIME=C date)."  >>"$LOGPATH"
	echo "${__mi}Command line: $CMDLINE" >>"$LOGPATH"
	for ((i=0; i<${#ARGS[@]}; i++)) do
		echo "${__mi}ARGS[$i] = ${ARGS[i]}" >>"$LOGPATH"
	done

	#  Toggling ondebug trap, as (((under certain circumstances))) it happens
	#  to block ^C sent from the terminal.
	bahelite_functrace_off
	#  When we will be exiting (even successfully), we will need to send
	#  SIGPIPE to that tee, so it would quit nicely, without terminating
	#  and triggering an error. It will, however, quit with a code >0,
	#  so we catch it here with “|| true”.
	case "$(get_bahelite_verbosity  log)" in
		0)	#  Not writing anything to log.
			;;

		1)	#  Writing only stderr to log.
			#
			#  If console verbosity (that is primary and not aware of whether
			#  logging would be enabled afterwards) has directed the stderr
			#  to /dev/null, it must be restored, and then the FD 2 must be
			#  redirected to the file in $LOGPATH.
			[ -v STDERR_ORIG_FD ] && {
				#  Restore the original FD 2 for the exec
				exec 2>&${STDERR_ORIG_FD}
			}
			if [ -v STDERR_ORIG_FD ]; then
				#  Console has directed FD 2 to /dev/null, so we’re free
				#    to take it and redirect it to the log, which needs
				#    that output.
				#  Moreover, we cannot make it so that FD 2 would point
				#    to /dev/null (for console) and still use the same FD 2
				#    to pipe output from commands to the log or to a subpro-
				#    cess with tee.
				exec 2>>"$LOGPATH"
			else
				exec 2> >(tee -ia "$LOGPATH" >&2 ||  true)
				BAHELITE_LOGGING_USES_TEE=t
			fi
			;;

		2|3|4|5|6|7|8|9)
			#  Writing stdout and stderr.
			#  The messages differ between levels 2 and 3:
			#    - on level 2 messages of info/abort/plainmsg level
			#      are forbidden in the messages module. The logging verbosity
			#      uses console settings here, this cannot be changed.
			#    - on level 3+ all messages are allowed.
			#
			#  Same story as above, expect that here we handle both
			#  stdout and stderr.
			#
			[ -v STDOUT_ORIG_FD ] && {
				#  Restore the original FD 1 for the exec
				exec 1>&${STDOUT_ORIG_FD}
			}
			if [ -v STDOUT_ORIG_FD ]; then
				#  Console doesn’t need this FD, but the log does.
				exec >>"$LOGPATH"
			else
				exec > >(tee -ia "$LOGPATH"  ||  true)
				BAHELITE_LOGGING_USES_TEE=t
			fi

			[ -v STDERR_ORIG_FD ] && {
				#  Restore the original FD 2 for the exec
				exec 2>&${STDERR_ORIG_FD}
			}
			if [ -v STDERR_ORIG_FD ]; then
				#  Console doesn’t need this FD, but the log does.
				exec 2>>"$LOGPATH"
			else
				exec 2> >(tee -ia "$LOGPATH" >&2 ||  true)
				BAHELITE_LOGGING_USES_TEE=t
			fi
			;;&

		6|7|8|9)
			exec {BASH_XTRACEFD}<>"$LOGDIR/${LOGNAME%.log}.xtrace.log"
			;;&

		7|8|9)
			set -x
			;;&

		9)	#  Be ready for metric tons of logs.
			unset BAHELITE_HIDE_FROM_XTRACE
			;;
	esac
	#  Restoring the trap on DEBUG
	bahelite_functrace_on

	BAHELITE_LOGGING_STARTED=t
	return 0
}
bahelite_extglob_off
#  No export: init stage function.


print_logpath() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	info "Log is written to
	      $LOGPATH"
	return 0
}
export -f  print_logpath


 # Returns absolute path to the last modified log in $LOGDIR.
#  [$1] – log name prefix, if not set, equal to $MYNAME
#         without .sh at the end (caller script’s own log).
#
set_lastlog_path() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	declare -gx LASTLOG_PATH
	local logname="${1:-}" lastlog_name
	[ "$logname" ] || logname=${MYNAME%.*}
	pushd "$LOGDIR" >/dev/null
	bahelite_noglob_off
	lastlog_name=$(ls -tr ${logname}_*.log | tail -n1)
	bahelite_noglob_on
	[ -f "$lastlog_name" ] || return 1
	popd >/dev/null
	LASTLOG_PATH="$LOGDIR/$lastlog_name"
	return 0
}
export -f  set_lastlog_path


 # Reads the contents of the log file by path set in LASTLOG_PATH
#    into LASTLOG_TEXT.
#  Also checks, if the last log has an error message, and if it does, then
#    copies the portion from where the error message starts in LASTLOG_TEXT
#    up to the end of file, and sets this text as the value for LASTLOG_ERROR
#    variable. The indicator of an error message is whatever is specified in
#    BAHELITE_ERR_MESSAGE_COLOUR varaible (should be set to $__r from the
#    bahelite_colours.sh). As all error handling functions in bahelite (that
#    is err, abort, errw and ierr) are final commands resulting in the call
#    to the “exit” builtin, there can be only one error message in the log.
#
read_lastlog() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	# declare -g LASTLOG_ERROR
	local err_msg_marker  err_msg_text
	set_lastlog_path "$@" || return $?
	declare -gx LASTLOG_TEXT
	#  Stripping control characters, primarily to delete colours codes.
	LASTLOG_TEXT=$(
		sed -r 's/[[:cntrl:]]\[[0-9]{1,3}[mKG]//g' "$LASTLOG_PATH"
	)
	 # Setting LASTLOG_ERROR is disabled, for it’s easier to just
	#  heave-ho the entire log into another log, than to parse its errors.
	#
	#  However, the following two methods can be consiedered:
	#  1. Finding “--- Call stack”
	#     Conditions:
	#       - the error must be caught by bahelite (some are still not).
	#       - catching one line before “--- Call stack” sometimes is very
	#         useful in understanding the real error.
	#     How to grab:
	#         log_call_stack=$(
	#             grep -B 1 -A 99999 '\-\-\- Call stack ' "$LASTLOG_PATH"
	#         )
	#  2. Finding the first entrance of the red colour, or whatever sequence
	#     is put into BAHELITE_ERR_MESSAGE_COLOUR.
	#     Conditions:
	#       - the error must be caught.
	#       - catching it is equally necessary as the error with call stack,
	#         because error messages with red colour are expected and there-
	#         fore, do not print the call stack. And vice versa unexpected
	#         errors do not use an error message, they just print the trace.
	#         So there are at least two types, and both of them are important.
	#     How to grab:
	#       Replace shell’s own alias for the escape sequence (\e)
	#       with its real hex code (\x1b), so that it could be used
	#       in the pattern for sed.
	#         err_msg_marker="${BAHELITE_ERR_MESSAGE_COLOUR//\\e/\\x1b}"
	#         err_msg_marker="${err_msg_marker//\[/\\\[}"
	#         sed -rn "/$err_msg_marker/,$ p" "$LASTLOG_PATH"
	#       or simply
	#         log_err_message=$(
	#             sed -rn "/\x1b\[31m/,$ p" "$LASTLOG_PATH"
	#         )
	#  3. Finding uncaught errors. There is no way to tell for sure,
	#       if a line in the log would, so, unless all of the error could be
	#       caught, it is more reasonable to perform all these checks from
	#       a script above the one, whose LOGPATH is parsed, i.e. the script call-
	#       ing the mother script. The script above should receive a non-zero
	#       exit code from the inner script, and this provides the reason
	#       to do every possible check for an error, including this one.
	#     Indeed, this check should be the last one among the three.
	#     How to grab:
	#         log_last_line=$(
	#             tac "$LASTLOG_PATH" | grep -vE '^\s*$' | head -n1  \
	#                 | sed -r "s/.*/$__mi&/" >&2
	#         )

	return 0
}
export -f read_lastlog


stop_logging() {
	[ -v BAHELITE_LOGGING_STARTED  -a  -v BAHELITE_LOGGING_USES_TEE ] && {
		#  Without this the script would seemingly quit, but the bash
		#    process will keep hanging to support the logging tee.
		#  Searching with a log name is important to not accidentally kill
		#    the mother script’s tee, in case one script calls another,
		#    and both of them use Bahelite.
		#
		#  Since the “tee” is made to ignore signals (tee -ia), there is no
		#    need to kill it, as the main process catches all the signals,
		#    and tee now receives SIGPIPE (or SIGHUP) in a natural way.
		#  Is this still needed?
		: pkill -PIPE  --session 0  -f "tee -ia $LOGPATH" || true

		#  Kills for sure
		# pkill -9  --session 0  -f "tee -ia $LOGPATH" || true

		#  Less reliable than -KILL, and leaves an ugly message
		# pkill -HUP  --session 0  -f "tee -ia $LOGPATH" || true
	}
	return 0
}
#  No export: it’s for bahelite_on_exit() function, that executes only
#  in top level context.



return 0