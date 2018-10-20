# Should be sourced.

#  bahelite_logging.sh
#  Organises logging and maintains logs in a separate folder.
#  deterenkelt © 2018

# Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	echo 'Must be sourced from bahelite.sh.' >&2
	return 5
}
. "$BAHELITE_DIR/bahelite_misc.sh" || return 5

# Avoid sourcing twice
[ -v BAHELITE_MODULE_LOGGING_VER ] && return 0
#  Declaring presence of this module for other modules.
BAHELITE_MODULE_LOGGING_VER='1.4'
REQUIRED_UTILS+=(
	date  #  to add date to $LOG file name and to the log itself.
	pkill  #  to find and kill the logging tee nicely, so it wouldn’t hang.
)
if [ -v BAHELITE_LOG_MAX_COUNT ]; then
	[[ "$BAHELITE_LOG_MAX_COUNT" =~ ^[0-9]{1,4}$ ]] \
		|| err "BAHELITE_LOG_MAX_COUNT should be a number,
		        but it is currently set to “$BAHELITE_LOG_MAX_COUNT”."
else
	BAHELITE_LOG_MAX_COUNT=5
fi


 # Call this function to start logging.
#  To keep logs under $CACHEDIR, run prepare_cachedir() before calling this
#  function, or logs will be written under $MYDIR.
#
start_log() {
	xtrace_off && trap xtrace_on RETURN
	declare -g BAHELITE_LOGGING_STARTED
	local arg
	if [ -v LOGDIR ]; then
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
	LOG="$LOGDIR/${MYNAME%.*}_$(date +%Y-%m-%d_%H:%M:%S).log"
	#  Removing old logs, keeping maximum of $LOG_KEEP_COUNT of recent logs.
	pushd "$LOGDIR" >/dev/null
	#  Deleting leftover variable dump.
	rm -f variables
	noglob_off
	( ls -r "${MYNAME%.*}_"* 2>/dev/null || : ) \
		| tail -n+$BAHELITE_LOG_MAX_COUNT \
		| xargs rm -v &>/dev/null || :
	noglob_on
	popd >/dev/null
	echo "Log started at $(LC_TIME=C date)." >"$LOG"
	echo "Command line: $CMDLINE" >>"$LOG"
	for ((i=0; i<${#ARGS[@]}; i++)) do
		echo "ARGS[$i] = ${ARGS[i]}" >>"$LOG"
	done
	#  When we will be exiting (even successfully), we will need to send
	#  SIGPIPE to that tee, so it would quit nicely, without terminating
	#  and triggering an error. It will, however, quit with a code >0,
	#  so we catch it here with “||:”.
	exec &> >(tee -a "$LOG" ||:)
	BAHELITE_LOGGING_STARTED=t
	return 0
}


show_path_to_log() {
	xtrace_off && trap xtrace_on RETURN
	if [ -v BAHELITE_MODULE_MESSAGES_VER ]; then
		info "Log is written to
		      $LOG"
	else
		cat <<-EOF
		Log is written to
		$LOG
		EOF
	fi
	return 0
}


 # Returns absolute path to the last modified log in $LOGDIR.
#  [$1] – log name prefix, if not set, equal to $MYNAME
#         without .sh at the end (caller script’s own log).
#
set_last_log_path() {
	xtrace_off && trap xtrace_on RETURN
	declare -g LAST_LOG_PATH
	local logname="${1:-}" last_log
	[ "$logname" ] || logname=${MYNAME%.*}
	pushd "$LOGDIR" >/dev/null
	noglob_off
	last_log=$(ls -tr ${logname}_*.log | tail -n1)
	noglob_on
	[ -f "$last_log" ] || return 1
	popd >/dev/null
	LAST_LOG_PATH="$LOGDIR/$last_log"
	return 0
}


read_last_log() {
	xtrace_off && trap xtrace_on RETURN
	set_last_log_path "$@" || return $?
	declare -g LAST_LOG
	#  Stripping control characters, primarily to delete colours codes.
	LAST_LOG=$(sed -r 's/[[:cntrl:]]\[[0-9]{1,3}[mKG]//g' "$LAST_LOG_PATH")
	return 0
}


return 0