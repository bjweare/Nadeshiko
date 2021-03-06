#  Should be sourced.

#  logging.sh
#  Selects logging directory and writes logs.
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
[ -v BAHELITE_MODULE_LOGGING_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_LOGGING_VER='1.8'
bahelite_load_module 'check_directory' || return $?
BAHELITE_INTERNALLY_REQUIRED_UTILS+=(
#	date   #  (coreutils) to add date to $LOGPATH file name and to the log itself.
#	ls     #  (coreutils)
	xargs  #  (findutils)
	pkill  #  (procps) to find and kill the logging tee nicely, so it wouldn’t
	       #           hang.
)


declare -gx BAHELITE_LOGGING_MAX_FILES=5

__show_usage_logging_module() {
	cat <<-EOF  >&2
	Bahelite module “logging” arguments:

	max_files=1..99999
	    How many log files to keep in the log directory. A number between
	    1 and 99999. The default is 5.
	EOF
	return 0
}


for arg in "$@"; do
	if  [[ "$arg" =~ ^max_files\=[0-9]{1,5}$ ]] && [ "$arg" -gt 0 ]; then
		BAHELITE_LOGGING_MAX_FILES="$arg"

	#
	#  The usage of cachedir (~/.cache/<main script name>/logs) for logs
	#  This module will use ~/.cache/… directory as long as no environment
	#  variable overrides LOGDIR or LOGPATH and the cachedir is prepared.
	#  Now for the cases, when it’s prepared (actually, almost always):
	#    - when you don’t specify BAHELITE_LOAD_MODULES (i.e. when bahelite.sh
	#      loads every module it can find – the full bundle includes a module
	#      for cachedir);
	#    - when you load a specific bunch of modules, and mention “cachedir”
	#      among others in BAHELITE_LOAD_MODULES array;
	#    - when you use BAHELITE_LOAD_MODULES and omit “cachedir” in the
	#      items, but use a parameter for the logging module instead, like
	#          BAHELITE_LOAD_MODULES=(
	#              "logging:use_cachedir"
	#          )
	#
	elif [ "$arg" = "use_cachedir" ]; then
		bahelite_load_module 'cachedir' || return $?

	elif [ "$arg" = help ]; then
		__show_usage_logging_module
		return 0

	else
		__show_usage_logging_module
		return 4
	fi
done
unset arg


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
	#
	#  In this order!
	#  Do not do “declare -gx BAHELITE_LOGGING_USES_TEE” if start_logging
	#  should quit! Exporting it will make the variable visible for [ -v … ]
	#  and this will cause a segmentation fault in stop_logging(), because
	#  “kill” command will attempt to kill something, that it shouldn’t.
	#
	declare -gx LOGPATH  LOGDIR
	[ "$(get_bahelite_verbosity  log)" == '0' ] && {
		LOGDIR="$TMPDIR"
		LOGPATH='/dev/null'
		return 0
	}
	#  In this order!
	declare -gx LOGNAME  BAHELITE_LOGGING_STARTED  BAHELITE_SHOW_UP_IN_XTRACE
	#  These are used only in the sameshell context.
	declare -g BAHELITE_LOGGING_USES_TEE  BAHELITE_LOGGING_TEE_CMD

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
	#           BAHELITE_DONT_CLEAR_TMPDIR or do it
	#           with a console (or log) verbosity
	#           level 5+, e.g. x5x or 5xx.)
	if [ -v LOGPATH ]; then
		touch "$LOGPATH" || {
			redmsg "Cannot write to LOGPATH specified in the environment:
			        $LOGPATH"
			err "LOGPATH is not writeable."
		}
		LOGDIR=${LOGPATH%/*}
		LOGNAME=${LOGPATH##*/}
		__check_directory "$LOGDIR"  'Logging'
		unset overwrite_logpath

	elif [ -v LOGDIR ]; then
		#  If LOGDIR is not a writeable directory, triggers an error.
		__check_directory "$LOGDIR"  'Logging'

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
		LOGNAME="${MYNAME_NOEXT}_$(date +%Y-%m-%d_%H:%M:%S).log"
		LOGPATH="$LOGDIR/$LOGNAME"
	}
	#  Must be set at one place, because it will be used in another
	#  function, that stops logging.
	BAHELITE_LOGGING_TEE_CMD=(tee -ia "$LOGPATH")
	#  Removing old logs, keeping maximum of $BAHELITE_LOGGING_MAX_FILES
	#  of recent logs.
	pushd "$LOGDIR" >/dev/null
	#  Deleting leftover variable dump.
	rm -f variables

	bahelite_noglob_off
	bahelite_extglob_on
	(ls -r "${MYNAME_NOEXT}_"+([_0-9:-]).log 2>/dev/null || true ) \
		| tail -n+$BAHELITE_LOGGING_MAX_FILES \
		| sed -r 's/\.log$//g;  s/\"/\\"/g'  \
		| xargs -I {} rm -fv  "{}.log" "{}.xtrace.log" &>/dev/null || true
	bahelite_extglob_off
	bahelite_noglob_on
	popd >/dev/null
	[ -v overwrite_logpath ]  \
		&& echo -n  >"$LOGPATH"
	echo "${__mi}Log started at $(LC_TIME=C date)."  >>"$LOGPATH"
	echo "${__mi}Command line: $CMDLINE" >>"$LOGPATH"
	for ((i=0; i<${#ORIG_ARGS[@]}; i++)) do
		echo "${__mi}ORIG_ARGS[$i] = ${ORIG_ARGS[i]}" >>"$LOGPATH"
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
				#  || true is needed only for non-nice, emergency and direct
				#  killing of the logging tee (Ctrl+F “Way II”).
				exec 2> >( "${BAHELITE_LOGGING_TEE_CMD[@]}" >&2 || true)
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
			[ -v BAHELITE_CONSOLE_VERBOSITY_SENT_STDOUT_TO_DEVNULL ] && {
				#  Restore the original FD 1 for the exec
				exec 1>&${STDOUT_ORIG_FD}
			}
			if [ -v BAHELITE_CONSOLE_VERBOSITY_SENT_STDOUT_TO_DEVNULL ]; then
				#  Console doesn’t need this FD, but the log does.
				exec >>"$LOGPATH"
			else
				#  || true is needed only for non-nice, emergency and direct
				#  killing of the logging tee (Ctrl+F “Way II”).
				exec > >( ${BAHELITE_LOGGING_TEE_CMD[@]} || true)
				BAHELITE_LOGGING_USES_TEE=t
			fi

			[ -v BAHELITE_CONSOLE_VERBOSITY_SENT_STDERR_TO_DEVNULL ] && {
				#  Restore the original FD 2 for the exec
				exec 2>&${STDERR_ORIG_FD}
			}
			if [ -v BAHELITE_CONSOLE_VERBOSITY_SENT_STDERR_TO_DEVNULL ]; then
				#  Console doesn’t need this FD, but the log does.
				exec 2>>"$LOGPATH"
			else
				#  || true is needed only for non-nice, emergency and direct
				#  killing of the logging tee (Ctrl+F “Way II”).
				exec 2> >( "${BAHELITE_LOGGING_TEE_CMD[@]}" >&2 || true)
				BAHELITE_LOGGING_USES_TEE=t
			fi
			;;&

		4|5|6|7|8|9)
			BAHELITE_XTRACE_ALLOWED=t
			;;&

		5|6|7|8|9)
			BAHELITE_MODULES_ARE_VERBOSE=t
			BAHELITE_DONT_CLEAR_TMPDIR=t
			;;&

		6|7|8|9)
			exec {BASH_XTRACEFD}<>"$LOGDIR/${LOGNAME%.log}.xtrace.log"
			;;&

		8|9)
			set -x
			;;&

		9)	#  Be ready for metric tons of logs.
			BAHELITE_SHOW_UP_IN_XTRACE=t
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
	lastlog_name=$(set +f;  ls -tr ${logname}_*.log | tail -n1)
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
	local  tee_pids=()
	local  tee_parents_pids=()
	local  use_pause

	__pause_if_needed() {
		[ -v use_pause ] || return 0
		echo -en "\n${__bri:-}Press any key to continue${__s:-} ${__g:-}>${__s:-} "
		read -n1
		echo -e '\n'
		return 0
	}

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

		[ -v BAHELITE_MODULES_ARE_VERBOSE ] && {
			echo
			info "Bahelite will now proceed to stop the logging processes."
			milinc
			[ -v BAHELITE_LOGGING_TEE_DEBUG_PAUSE ]  \
				&& use_pause=t  \
				|| info "Need a pause?
				         There is a helper variable BAHELITE_LOGGING_TEE_DEBUG_PAUSE.
				         Set it to any value before calling the main script, e.g.
				             BAHELITE_LOGGING_TEE_DEBUG_PAUSE=t  ./my_script.sh
				         and it will wait for a keypress between the stages of this
				         process."
			echo
			declare -p ORIG_BASHPID  BASHPID  ORIG_PPID  PPID
			echo
			ps -o session,pgid,ppid,pid,s,args --forest -s $ORIG_PPID  || {
				warn "Our own PPID didn’t start the process session we’re in.
				      Are we running from another script?"
				ps -o session,pgid,ppid,pid,s,args  \
				   --forest  \
				   -s /proc/$ORIG_PPID/sessionid
			}
			echo
		}

		 # There are several ways to stop logging. The nicest one is preferred.
		#
		#  Way I. Finding the parent shells of the logging tee processes
		#         and closing them.
		#  − Somewhat slower than doing it not nicely (but not noticeably slow
		#    for the user).
		#  + No ugly messages to console.
		#  + Clean exit. All shells and processes quit with zero code, so
		#    there can be no false errors. If an error happens, this means,
		#    that it is a real error and something went wrong.
		#
		#
		 # Finding PIDs of the logging tee processes themselves
		#  “--session 0” is pgrep syntax for process’s own session id.
		#    It works fine for both standalone main scripts and for main
		#    scripts that run from within another main script.
		#  $ORIG_PPID may be used instead of it ONLY if the main script
		#    is standalone (not running from within another main script, that
		#    itself uses bahelite – then session id will belong to the higher
		#    main script’s PPID, and ALL underlying processes including the
		#    internal main script and its subprocesses, in which tee is run-
		#    ning, they all will have that as session id)
		#
		tee_pids=(
			$(pgrep --session 0  -f "${BAHELITE_LOGGING_TEE_CMD[*]}" || true)
		)
		[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
			&& info "TEE PIDS: ${tee_pids[*]} (${#tee_pids[*]} in total)."

		#  Something has killed logging tees before us. If they somehow hanged,
		#  the user might have pkill’ed them by hand or something. Anyway,
		#  this function should close logging, and there is already nothing
		#  to close, so we’re quitting.
		(( ${#tee_pids[*]} == 0 )) && return 0

		[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
			&& __pause_if_needed

		tee_parents_pids=( $(ps h -o ppid "${tee_pids[@]}" || true) )
		[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
			&& info "TEE PARENTS PIDS: ${tee_parents_pids[*]} (${#tee_parents_pids[*]} in total)."

		(( ${#tee_parents_pids[*]} == ${#tee_pids[*]} )) && {

			[ -v BAHELITE_MODULES_ARE_VERBOSE ] && {
				__pause_if_needed
				info 'Killing tees by sending HUP to their shells:'
			}

			 # When the subprocesses, that hold logging tee processes, are
			#  killed, bash prints their PIDs to console. This cannot be
			#  avoided with a simple stream redirection like
			#      exec {TEMP_STDERR_FD}>&2
			#      kill -TERM "${tee_parents_pids[@]}"
			#      exec 2>&${TEMP_STDERR_FD}
			#  as once the remembered FD for stderr is restored, it prints
			#  the accumulated contents. And no, neither read, nor readarray,
			#  nor even read inside while with the descriptor passed via the
			#  -u switch can flush the contents. The only way is to shut down
			#  stderr and stdout completely.
			#
			#  Thankfully, stop_logging is called at the very end of the trap
			#  on EXIT, i.e. bahelite_on_exit and is literaly the last executed
			#  command. There is nothing past this function, traps on signals
			#  are already unset at this point. So it’s comparatively safe
			#  to close stdout and stderr.
			#
			#  As a measure to ease the debugging, stdout and stderr are closed
			#  only when the verbosity stays on the default, user-friendly
			#  level (i.e. not higher than 3 for console or the log file).
			#  Once the verbosity level is raised, stdout and stderr will remain
			#  intact and let out the PIDs show in the console, along with
			#  the messages that may come after this. (Though in regular use
			#  no messages should be shown).
			#
			[ -v BAHELITE_MODULES_ARE_VERBOSE ] || {
				exec 2>/dev/null
				exec >/dev/null
			}

			 # “kill -HUP” caused a segmentation fault before. Read the comment
			#    above the initial declarations in start_logging().
			#  There is an evidence retrieved with consolve verbosity level 5,
			#    that -TERM does not kill the tee parents – tee processes are
			#    still there after 10 seconds, and this function has to go
			#    Way II to deal with them.
			#  However, it works fine like it is, and it is undesirable
			#    to touch a working system. Killing parents with -INT won’t
			#    kill tees. Maybe sending -PIPE to them is not quite clean
			#    (tee commands themselves must be shielded with “|| true”),
			#    but at least there was no spam to console – even without
			#    the redirection to /dev/null above. So, touching it is unde-
			#    sirable.
			#
			kill -TERM "${tee_parents_pids[@]}"

			[ -v BAHELITE_MODULES_ARE_VERBOSE ]  && {
				__pause_if_needed
				info 'Testing if the processes still hang there:'
			}

			#  No processes = BAD from pgrep, GOOD for us – they are closed,
			#  as they should be. So “… || return 0”. All done.
			pgrep --session 0  -f "${BAHELITE_LOGGING_TEE_CMD[*]}"  \
				|| return 0
		}


		[ -v BAHELITE_MODULES_ARE_VERBOSE ] && {
			echo
			info "Normally, logging processes are already stopped at this point
			      and $FUNCNAME() returns – the code past this point never runs.

			      However, when the debugging level is raised, $FUNCNAME doesn’t
			      close stdout and stderr file descriptors. Because of this, the
			      code above wasn’t able to close the logging tee processes grace-
			      fully (as it normally does). $FUNCNAME will have to resort to
			      a less graceful solution, that’s placed between this code and
			      the end of the function. Remember, that if the verbosity levels
			      were set at their default values, this function would already
			      quit. See also the comments in the body of this function."

			      #  Keeping stdout and stderr open at a raised verbosity level
			      #  is done to show as much debugging output as possible. The
			      #  debugging of this very function would not be feasible
			      #  without holding stdout and stderr open until the last mo-
			      #  ment, that allows to have a clean exit from the program.

			__pause_if_needed
			mildec
		}


		 # Way II. Sending pkill -PIPE to tee processes
		#  + Fast.
		#  + Doesn’t leave any ugly messages to console.
		#  − It doesn’t make a clean exit.
		#    As this essentially abruptly kills the tee processes, they
		#    will quit with a negative result, what will trigger additional
		#    errors. To avoid that, “|| true” must be added inside the sub-
		#    shell call >( … ) with exec in start_logging() above.
		#
		pkill -PIPE  --session 0  -f "${BAHELITE_LOGGING_TEE_CMD[*]}" || true


		 # Way III. Sending pkill -KILL to tee processes.
		#  + Fast.
		#  − Leaves ugly messages to console.
		#  − It doesn’t make a clean exit (see way II).
		#
		# pkill -KILL  --session 0  -f "tee -ia $LOGPATH" || true
	}
	return 0
}
#  No export: it’s for bahelite_on_exit() function, that executes only
#  in top level context.


BAHELITE_POSTLOAD_JOBS+=( "start_logging:after=prepare_cachedir" )


return 0