# Should be sourced.

#  bahelite_error_handling.sh
#  Places traps on signals ERR, EXIT group and DEBUG. Catches even those
#    errors, that do not trigger sigerr (errexit is imperfect and doesn’t
#    catch nounset and arithmetic errors).
#  On error prints call trace, the failed command and its return code,
#    all highlighted distinctively.
#  Each trap calls user subroutine, if it’s defined (subroutine should
#    have the same name sans the “bahelite_” prefix).
#  © deterenkelt 2018–2019

# Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	echo "Bahelite error on loading module ${BASH_SOURCE##*/}:"  >&2
	echo "load the core module (bahelite.sh) first."  >&2
	return 4
}

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_ERROR_HANDLING_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_ERROR_HANDLING_VER='1.6.4'
BAHELITE_INTERNALLY_REQUIRED_UTILS+=(
#	mountpoint   # (coreutils) Prevent clearing TMPDIR, if it’s a mountpoint.
)



 # Stores values, that environment variable $LINENO takes, in an array.
#
#  There are three types of errors in bash.
#  1. The ones that trigger SIGERR and are caught simply by placing
#     a trap on that signal (implying that you use “set -E”).
#     To stop the script from executing, errexit is enough (set -e);
#  2. Errors that DON’T trigger SIGERR and the corresponding trap,
#     but make the script stop. If you wanted to print a call stack or do
#     something else – this all would be bypassed. Errors of this type
#     include “unbound variable”, caused when nounset option is active
#     (set -u). The script is stopped automatically, but the trap on EXIT
#     must catch the bad return value and call trap on ERR to print
#     call stack.
#  3. Error that neither trigger SIGERR, nor do they stop the script.
#     These are the most nasty ones: you get an error, but the code continues
#     to run! No way to catch, if they happened. Arithmetic errors, such as
#     division by (a variable, that has a) zero is one example of this type.
#
#  The only way to catch the errors of type 2 is to pass the exit code
#     of the last command to the trap on EXIT, and if it’s >0, call
#     the trap on ERR, however, both BASH_LINENO and LINENO will be
#     useless in printing the right call stack:
#     - BASH_LINENO will always have “1” for the line, that actually triggered
#       the error, or at best may point to the function definition (not to the
#       line in it), where the error occurred.
#     - LINENO just cannot be used, because it stores only one value –
#       the number of the current line, which, if referenced inside
#       of a trap, would point to the command inside the trap, or,
#       if passed to a trap as an argument, would actually pass the
#       line number, where that trap is defined. Basically useless here.
#
#  This array is used to store $LINENO values, so that the trap on EXIT
#    could get the actual line number, where the error happened, and pass it
#    to the trap on ERR. Having it and knowing, that it’s called from the
#    trap on exit, trap on ERR can now substitute the wrong line numbers
#    from BASH_LINENO with the number passed from the trap on EXIT and print
#    the call stack the right way independently of whether a bash error
#    triggered SIGERR or not.
#
#  It works in the global (i.e. “main” function’s) scope, as well as inside
#    functions, sourced scripts and functions inside them.
#
#  Sharp ones among you may wonder “What about errors of the third type?”
#    The answer is: it’s not possible to catch them. You have to know,
#    what triggers them and use constructions, that prevent these errors
#    from appearing, so that there won’t be a single chance of main script
#    failing there.
#  Catching the errors of type 2 already requires a trap on DEBUG signal.
#    I’ve made a prototype of this module, that uses this trap to also check
#    the return value of the last executed command. Much like the trap
#    on EXIT does, but “one step before”. It was possible to catch a line like
#        $((  1/0  ))
#    but the trap on DEBUG could not be used. Yes, because it doesn’t
#    differentiate between simple commands and those running in “for”, “while”
#    and “until” cycles; it catches first command in an && or || statement,
#    catches the first command in a pipe without “pipefail” option set.
#    In other words, it would require another array for storing BASH_COMMAND
#    values, looking there for cycles, pipes and logical operators – and there
#    still won’t be a guarantee, that it will be done right.
#  Thus, the only way to avoid type 3 errors is to know them and use
#    constructions in your code, that exclude any possibility
#    of these errors happening.
#  P.S. this trap on debug is also useless for catching forgotten backslashes
#    in compound logic statements like
#        if  (
#              command1 \
#              && command2 \
#              && command3
#            )  # <-- forgotten backslash
#            ||
#            foovar=bar
#        then
#            …
#        fi
#
declare -gax BAHELITE_STORED_LNOS=()


 # Helps to build a meaningful stack trace, when an error is encountered.
#    Due to the different nature of bash errors – see the huge comment above –
#    the regular means are not sufficient.
#  Requires trap on debug to be set and functions, subshells and command sub-
#    stitutions to inherit it, i.e.  bahelite_toggle_ondebug_trap  must be
#    called below to set DEBUG trap and the mother script should have “set -T”.
#
bahelite_on_each_command() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local i line_number="$1"
	# We don’t need more than two stored LINENO’s:
	# - one for the failed command we want to catch,
	# - and one that inevitably caused by calling this trap.
	local lnos_limit=2
	for ((i=${#BAHELITE_STORED_LNOS[@]}; i>0; i--)); do
		BAHELITE_STORED_LNOS[i]=${BAHELITE_STORED_LNOS[i-1]}
	done
	[ ${#BAHELITE_STORED_LNOS[@]} -eq $((lnos_limit+1)) ] \
		&& unset BAHELITE_STORED_LNOS[$lnos_limit]
	BAHELITE_STORED_LNOS[0]=$line_number
	# Call user’s on_debug(), if defined.
	[ "$(type -t on_debug)" = 'function' ] && on_debug
	#  Output to stdout during DEBUG trap may produce unwanted output
	#    into $(subshell calls), so you better NEVER output anything
	#    in traps on DEBUG, or at least always use >&2 and make sure
	#    you never add stderr to stdout in $(subshell calls) like $(… 2>&1).
	#  Xdialog has --stdout option to produce output in stdout instead
	#    of stderr.
	# echo "${BAHELITE_STORED_LNOS[*]}" >&2
	return 0
}
export -f  bahelite_on_each_command


 # Trap on DEBUG is a part of the system, that helps to build a meaningful
#    call trace in case when an error happens.
#  Trap on DEBUG is temporarily disabled for the time xtrace shell option
#    is enabled in the mother script. This is handled in the set builtin
#    wrapper in bahelite.sh.
#  Trap on DEBUG may cause the script hang on pipes (still in bash 4.4) –
#    to check, if -T can cause your script hang, try adding to the main script
#    the following code:
#        set -T
#        echo "something" | xclip
#    It can also may make the main script miss signals like SIGINT and even
#    SIGQUIT, if you do a call like exec in start_logging() in bahelite_logging.sh,
#    without temporarily switching off functrace and disabling the trap
#    on DEBUG. However, this occurs only under uncertain circumstances and may
#    depend on the host. A thorough comparison between two hosts, one on which
#    the issue is observed and the other, where it isn’t, has shown NO DIFFE-
#    RENCES between:
#      - shell options in $- variable
#      - shell options in set -o
#      - shell options in shopt -p
#      - TERM variable
#      - stty output
#      - I/O file descriptors, used in the main shell and subshell (except
#        for the pipe:XXXXXXXXX numbers)
#      - traps being set in the main script and within >( … )
#        (Running “trap '' DEBUG RETURN” within >( … ) also didn’t help.)
#    The comparison was indeed performed without temporary disabling functrace
#    and unsetting the trap on DEBUG.
#  So, if you want to catch errors better with this trap on DEBUG, but get
#    reports, that at some places, where pipes or process substitution are
#    involved, the recommended way to solve it is:
#        set +T
#        <your code>
#        set -T
#    This will control both the functrace shell option and set/unset the trap
#    on DEBUG, as needed.
#
bahelite_toggle_ondebug_trap() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	case "$1" in
		set)
			#  Note the single quotes – to prevent early expansion
			trap 'bahelite_on_each_command "$LINENO"' DEBUG
			;;
		unset)
			#  trap '' DEBUG will ignore the signal.
			#  trap - DEBUG will reset command to 'bahelite_on_each_command… '.
			trap '' DEBUG
			;;
	esac
	return 0
}
export -f  bahelite_on_each_command


 # This trap handles various signals that cause bash to quit.
#  SIGEXIT is handled, because not all errors trigger SIGERR. Because of that,
#    when the program wants to quit “normally” on EXIT, we should check the
#    data collected in bahelite_on_each_command() – the trap on DEBUG – first,
#    to know whether there was some failed command or instruction, and if
#    there is, throw an error message to desktop and print the call stack
#    to the log. If we won’t do it, then on the user side this will seem like
#    a silent failure. Nasty.
#  SIGQUIT is always ignored by bash. On catching SIGQUIT bash only prints
#    “Quit”, “Segmentation fault” and no trap is processed.
#  SIGKILL forcibly wipes the process from the memory, this doesn’t leave any
#    possibility to handle this case. Just as planned by the OS, actually.
#  SIGINT, SIGTERM, SIGHUP and SIGPIPE all are common causes of forced termi-
#    nation, and these four signals are successfully handled with bash traps.
#
bahelite_on_exit() {
#   builtin set +x
	local command="$1"  retval="$2"  stored_lnos="$3"  signal="$4"  \
	      current_varlist  varname
	mildrop
	#  Normally, when a subshell exits, trap on EXIT is called is the main
	#    shell. However, if called explicitly, e.g. from another trap – on ERR
	#    for example (Bahelite doesn’t do that) it may be called in the sub-
	#    shell context. Nesting subshells, as a rule, do not make the trap
	#    on EXIT run in subshell context too. So this check here is just
	#    in case.
	#  Disabled for it prevents catching signals like INT.
	#
	# (( BASH_SUBSHELL > 0 )) && {
	# 	trap '' EXIT TERM INT HUP PIPE  ERR  RETURN  DEBUG
	# 	exit $?
	# }

	#  Like with BAHELITE_ERROR_PROCESSED and bahelite_show_error, there is
	#  a situation, when the same trap may be called twice, though it is
	#  unnecessary. The reason here is that after SIGINT bash calls SIGEXIT,
	#  and as both signals are processed by this same function, there is
	#  no need to process what already was processed.
	[ -v BAHELITE_EXIT_PROCESSED ]  \
		&& return 0  \
		|| declare -gx BAHELITE_EXIT_PROCESSED=t

	#  Catching internal bash errors, like “unbound variable”
	#    when using nounset option (set -u). These errors
	#    do not trigger SIGERR, so they must be caught on exit.
	#  If the main script runs in the background, the user
	#    won’t even see an error without this.
	#  “exit” is the only command that allowed to quit with non-zero safely.
	#    It implies, that the error was handled.
	#  There are cases, when one has to catch a bad exit code from a subshell,
	#    like with
	#      $( … ) || exit $?
	#    But the “exit” directive is tricky here. Normally, one uses “exit” in
	#    two cases: when exit status is clean, i.e. equals 0, and when an error
	#    is already shown, e.g. when err() was called inside the subshell – it
	#    has already displayed an error to the user, it just couldn’t stop the
	#    main script – so we run exit afterwards in “… || exit $?”. But the
	#    subshell code may still catch a bash error. And since the subshell is
	#    a part of an OR statement (i.e. “…||…”), the proper signal – SIGERR – 
	#    won’t be triggered. The error will make the script stop, but it will
	#    bypass the trap on SIGERR, and this means, that neither in the con-
	#    sole, nor in the log will be a mention WHY the script stopped – this
	#    would look like it just stopped normally. This is called a “silent
	#    failure”.
	#  To prevent that, the condition below does a check on the actual number
	#    in the return code – if it’s 1 or 2, that would most likely be an
	#    uncaught bash error. And they will go by the “else” clause here,
	#    to bahelite_show_error().
	#
	[ "$signal" = 'EXIT' ]  &&  (( retval > 0  &&  retval != 6 ))  &&  {
		if [[ "$command" =~ ^exit[[:space:]] ]]  &&  ((retval >= 5)); then
			#  If it was exit that the author of the main script caught
			#  with err() or errw()
			bahelite_print_call_stack
			bahelite_noglob_off
			if	[ -v BAHELITE_STIPULATED_ERROR ] \
				|| [ -r "$TMPDIR/BAHELITE_STIPULATED_ERROR_IN_SUBSHELL."* ]
			then
				[ "$(type -t on_error)" = 'function' ] && on_error
			fi
			bahelite_noglob_on
		else
			[ ! -v BAHELITE_ERROR_PROCESSED ]  \
				&& bahelite_on_error "$command"  \
				                     "$retval"  \
				                     "from_on_exit"  \
				                     "${stored_lnos##* }"
			#  ^ user’s on_error() will be launched from within
			#    bahelite_on_error()
		fi
	}
	#  Run user’s on_exit(). Keep in mind, that at this point
	#  $? is already frozen.
	[ "$(type -t on_exit)" = 'function' ] && on_exit
	#  Stop logging, if started
	[ "$(type -t stop_logging)" = 'function' ] && stop_logging
	[ -v BAHELITE_DUMP_VARIABLES ] && {
		current_varlist=$(
			compgen -A variable  \
				| grep -vE 'BAHELITE_VARLIST_(BEFORE|AFTER)_STARTUP'
		)
		for varname in \
			$(
				echo "$BAHELITE_VARLIST_AFTER_STARTUP"$'\n'"$current_varlist" \
					| sort | uniq -u | sort
			)
		do
			declare -p "$varname"  &>>"${LOGDIR:-$TMPDIR}/variables"
		done
	}
	if	[ -d "$TMPDIR" ] && ! mountpoint --quiet "$TMPDIR" \
		&& [ ! -v BAHELITE_DONT_CLEAR_TMPDIR ]
	then
		#  Remove TMPDIR only after logging is done.
		rm -rf "$TMPDIR"
	fi
	[ "$signal" != 'EXIT' ] && err "Caught SIG$signal."
	return 0
}
#  No export: runs only on the top level, using it inside of subshell is not
#  necessary (exit from subshells are caught and handled) and could cause
#  harm, if would run twice.


bahelite_print_call_stack() {
	#  Skip only 3 levels (this very function, __msg and err*/abort), when
	#  printing the call stack.
	local  levels_to_skip
	local  from_on_exit="${1:-}" real_line_number="${2:-}"   \
	       line_number_to_print  f  i term_cols=$TERM_COLS
	[[ "$-" =~ .*i.* ]] || term_cols=80
	[ -v BAHELITE_HIDE_FROM_XTRACE ] \
		&& levels_to_skip=3  \
		|| levels_to_skip=0
	echo -en "${__bright:-}--- Call stack " >&2
	for ((i=0; i<term_cols-15; i++)); do  echo -n '-';  done
	echo -e "${__stop:-}" >&2
	for ((f=${#FUNCNAME[@]}-1; f>levels_to_skip; f--)); do
		#  Hide on_exit and on_error, as the error only bypasses through
		#  there. We don’t show THIS function in the call stack, right?
		[ "${FUNCNAME[f]}" = bahelite_on_error ] && continue
		[ "${FUNCNAME[f]}" = bahelite_on_exit ] && continue
		line_number_to_print="${BASH_LINENO[f-1]}"
		#  If the next function (that’s closer to this one) is on_exit,
		#  this means, that FUNCNAME[f] currently holds the name
		#  of the function, where the error occurred, and its
		#  line number should be replaced with the real one.
		[ "$from_on_exit" = from_on_exit ] && {
			[ "${FUNCNAME[f-2]}" = bahelite_on_exit ] && {
				line_number_to_print="$real_line_number"
			}
		}
		# echo "Printing FUNCNAME[$f], BASH_LINENO[$((f-1))], BASH_SOURCE[$f]"
		echo -en "${__bri:-}${FUNCNAME[f]}${__s:-}, " >&2
		echo -e  "line $line_number_to_print in ${BASH_SOURCE[f]}" >&2
	done
	return 0
}
export -f  bahelite_print_call_stack


bahelite_on_error() {
	#  Disabling xtrace, for even if the programmer has put set +x where
	#  needed, but the program catches an error before that all, there will be
	#  a lot of trace, that the programmer doesn’t need.
	builtin set +x
	trap '' DEBUG
	declare -gx BAHELITE_DUMP_VARIABLES  \
	            BAHELITE_DONT_CLEAR_TMPDIR  \
	            BAHELITE_ERROR_PROCESSED
	local failed_command=$1  failed_command_code=$2  from_on_exit="${3:-}"  \
	      real_line_number=${4:-}  log_path_copied_to_clipboard  varname  \
	      current_varlist  term_cols=$TERM_COLS
	[[ "$-" =~ .*i.* ]] || term_cols=80
	BAHELITE_DUMP_VARIABLES=t   # This is for bahelite_on_exit().
	[ -v LOGDIR ] || BAHELITE_DONT_CLEAR_TMPDIR=t   # This too.
	mildrop
	#  Since an error occurred, let all output go to stderr by default.
	#  Bad idea: to put “exec 2>&1” here
	#  Run user’s on_error().
	[ "$(type -t on_error)" = 'function' ] && on_error
	#  If this is a stipulated error, that happened in a subshell,
	#  and because of that, the call to err() did only make the subshell
	#  exit(), and not the main script, the must not treat it as an unhandled
	#  error.
	if	(( failed_command_code >= 5 )) \
		&& [ -r "$TMPDIR/BAHELITE_STIPULATED_ERROR_IN_SUBSHELL.$BAHELITE_STARTUP_ID" ]
	then
		return 0
	fi

	bahelite_print_call_stack "${from_on_exit:-}" "${real_line_number:-}"

	echo -en "Command: " >&2
	(	echo -en  "${__bri:-}$failed_command${__s:-} "
		echo -en  "${__r:-}${__bri:-}(exit code: $failed_command_code)${__s:-}."
		)	| fold -w $((term_cols-9)) -s \
			| sed -r '1 !s/^/         /g' >&2
	echo
	#  SIGERR is triggered, when the last executed command has $? ≠ 0.
	#  However, bash will also issue SIGEXIT afterwards (as it always does
	#  except for after SIGQUIT, as that belongs to the group of “core dump”
	#  signals, and this is probably the reason why pressing C-\ in the
	#  terminal ends with a “Segmentation fault” message and SIGEXIT is never
	#  issued). And as the SIGEXIT trap may call bahelite_on_error – because
	#  it catches even those errors, that do not trigger a SIGERR – we need
	#  to avoid calling bahelite_on_error recursively. For that we set
	#  BAHELITE_ERROR_PROCESSED to indicate, that there is no need to call
	#  this function twice.
	BAHELITE_ERROR_PROCESSED=t
	if [ -v BAHELITE_LOGGING_STARTED ]; then
		which xclip &>/dev/null && {
			echo -n "$LOGPATH" | xclip
			log_path_copied_to_clipboard='\n\n(Path to the log file is copied to clipboard.)'
		}
		[ "$(type -t bahelite_notify_send)" = 'function' ]  \
			&& bahelite_notify_send "Bash error. See the log.${log_path_copied_to_clipboard:-}"   \
			                         error
		print_logpath
	else
		[ "$(type -t bahelite_notify_send)" = 'function' ]  \
			&& bahelite_notify_send "Bash error. See console." error
		warn "Logging wasn’t enabled in $MYNAME.
		      Call start_logging() someplace after sourcing bahelite.sh to enable logging.
		      If prepare_cachedir() is used too, it should be called before start_logging()."
	fi
	return 0
}
#  No export: must not be used in subshell context (for the same reason as
#  bahelite_on_exit() function above).


 # When it is needed to disable the errexit shell option (you usually do this
#    with “set +e”), the SIGERR is still triggered – it only doesn’t make the
#    rogram quit any more. And the trap associated with SIGERR, keeps running.
#    The programmer of the mother script doesn’t expect this, and thus
#    it creates a problem.
#  The trap on SIGERR is useful, when errexit is on: when an error happens,
#    the trap prints the details and does necessary stuff. When errexit
#    is unset, this trap becomes more of an inconvenience, rather than
#    adding usefulness. As the program will not stop, it may trigger multiple
#    SIGERR signals, which may be very confusing.
#  If the trap on SIGERR would run multiple times (because errexit is unset),
#    the prgrammer might think, that the library went insane. This is another
#    confusion, that must be prevented.
#  The state of errtrace shell option (set -E), that is often enabled together
#    with “set -e”, is not touched in any way, because this is not necessary.
#    Shell functions, subshells and substitutions will continue to inherit
#    whatever is associated with the signal, and we here change that very
#    association. Inheritance may be left as is – it doesn’t create any poten-
#    tial issue.
#
bahelite_toggle_onerror_trap() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	case "$1" in
		set)
			#  Note the single quotes – to prevent early expansion
			trap 'bahelite_on_error "$BASH_COMMAND" "$?"' ERR
			;;
		unset)
			#  trap '' ERR will ignore the signal.
			#  trap - ERR will reset command to 'bahelite_show_error… '.
			trap '' ERR
			;;
	esac
	return 0
}
#  No export: must not be used in subshell context.



trap 'bahelite_on_exit "$BASH_COMMAND" "$?" "${BAHELITE_STORED_LNOS[*]}" EXIT' EXIT
trap 'bahelite_on_exit "$BASH_COMMAND" "$?" "${BAHELITE_STORED_LNOS[*]}" TERM' TERM
trap 'bahelite_on_exit "$BASH_COMMAND" "$?" "${BAHELITE_STORED_LNOS[*]}"  INT'  INT
trap 'bahelite_on_exit "$BASH_COMMAND" "$?" "${BAHELITE_STORED_LNOS[*]}"  HUP'  HUP
trap 'bahelite_on_exit "$BASH_COMMAND" "$?" "${BAHELITE_STORED_LNOS[*]}" PIPE' PIPE
#
#  Traps on ERR and DEBUG signals may need to be toggled,
#  hence activated through their own wrappers.
#
bahelite_toggle_onerror_trap  set
#
#  The trap on DEBUG has a meaning to be set only when functrace shell option
#    is activated in the main script (usually with “set -T”), so on top of
#    the wrapper there is another check.
#  Trap on DEBUG is necessary for the better error handling. See also
#    the descriptions above to these functions:
#    - bahelite_on_each_command;
#    - bahelite_toggle_ondebug_trap;
#    - bahelite_on_exit.
#
[ -o functrace ]  \
	&& bahelite_toggle_ondebug_trap  set

return 0