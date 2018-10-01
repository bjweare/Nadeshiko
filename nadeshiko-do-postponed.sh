#! /usr/bin/env bash

#  nadeshiko-do-postponed.sh
#  Wrapper for Nadeshiko to encode postponed files.
#  deterenkelt © 2018
#
#  For licence see nadeshiko.sh


set -feEuT
. "$(dirname "$0")/lib/bahelite/bahelite.sh"
prepare_cachedir 'nadeshiko'
start_log
set_libdir 'nadeshiko'
set_exampleconfdir 'nadeshiko'
prepare_confdir 'nadeshiko'

declare -r rcfile_minver='2.0'
declare -r version="2.1"
declare -r failures_logdir="$LOGDIR/postponed_failures"
declare -r postponed_commands="$CACHEDIR/postponed_commands"
declare -r postponed_commands_dir="$CACHEDIR/postponed_commands_dir"

read_rcfile  "$rcfile_minver"
[ "${taskset_cpulist:-}" ] && {
	[[ "$taskset_cpulist" =~ ^[0-9,-]+$ ]] \
		|| err 'Invalid CPU list for taskset.'
	REQUIRED_UTILS+=(taskset)
	taskset_cmd="taskset --cpu-list $taskset_cpulist"
}
[ "${niceness_level:-}" ] && {
	[[ "$niceness_level" =~ ^-?[0-9]{1,2}$ ]] \
		|| err 'Invalid level for nice.'
	REQUIRED_UTILS+=(nice)
	nice_cmd="nice -n $niceness_level"
}
check_required_utils

single_process_check
pgrep -u $USER -af "bash.*nadeshiko.sh" &>/dev/null  \
	&& err 'Cannot run at the same time with Nadeshiko.'
pgrep -u $USER -af "bash.*nadeshiko-mpv.sh" &>/dev/null  \
	&& err 'Cannot run at the same time with Nadeshiko-mpv.'



 # Process $postponed_commands as a file with multiple commands (old format)
#  There’s a weird bug when this was done a simpler way – gathering path
#    to executable and args and then launching "${comcom[@]}", when an empty
#    line is read. Somehow, parts of ffmpeg output still got to the terminal,
#    and after Nadeshiko was called once, the next line read from postponed
#    was Time2 or the line with source video.
#  Avoiding this bug by assembling all commands first and running them later.
process_file() {
	local i=0  comcom_0=()  ref  com  last_log
	while IFS= read -r -d $'\n'; do
		if [ "$REPLY" ]; then
			declare -n ref=comcom_$i
			ref+=("$REPLY")
		else
			let ++i
			declare -a comcom_$i
		fi
	done < "$postponed_commands"

	for com in ${!comcom*}; do
		declare -n ref=$com
		echo -e "\n${ref[@]}"
		${nice_cmd:-} ${taskset_cmd:-} "${ref[@]}" || {
			[ -d "$failures_logdir" ] || mkdir "$failures_logdir"
			if last_log=$(get_last_log nadeshiko); then
				cp "$last_log" "$failures_logdir"
			else
				warn "Cannot get last log."
			fi
		}
	done

	rm -f "$postponed_commands"
	return 0
}


 # Process $postponed_commands_dir (new format)
#
process_dir() {
	local last_log
	while IFS= read -r -d ''; do
		${nice_cmd:-} ${taskset_cmd:-} "$REPLY" || {
			[ -d "$failures_logdir" ] || mkdir "$failures_logdir"
			if last_log=$(get_last_log nadeshiko); then
				cp "$last_log" "$failures_logdir"
			else
				warn "Cannot get last log."
			fi
		}
		rm "$REPLY"
	done < <( find "$postponed_commands_dir" -type f -print0 )
	return 0
}


#  Finishing tasks from the single file, which is deprecated.
[ -f "$postponed_commands" ] && process_file
#  Doing tasks from the directory, the new way.
[ -d "$postponed_commands_dir" ] && process_dir


exit 0