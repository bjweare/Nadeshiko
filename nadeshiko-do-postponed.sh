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
declare -r version="2.0"
declare -r failures_logdir="$LOGDIR/postponed_failures"
declare -r postponed_commands="$CACHEDIR/postponed_commands"

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

rm -rf "$failures_logdir"

 # There’s a weird bug when this was done a simpler way – gathering path
#    to executable and args and then launching "${comcom[@]}", when an empty
#    line is read. Somehow, parts of ffmpeg output still got to the terminal,
#    and after Nadeshiko was called once, the next line read from postponed
#    was Time2 or the line with source video.
#  Avoiding this bug by assembling all commands first and running them later.
i=0
comcom_0=()
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
exit 0
