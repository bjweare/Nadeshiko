#! /usr/bin/env bash

#  nadeshiko-do-postponed.sh
#  Wrapper for Nadeshiko to encode postponed files.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh


set -feEuT
BAHELITE_CHERRYPICK_MODULES=(
	error_handling
	logging
	rcfile
	misc
)
mypath=$(dirname "$(realpath --logical "$0")")
case "$mypath" in
	'/usr/bin')
		source "/usr/lib/nadeshiko/bahelite/bahelite.sh";;
	'/usr/local/bin')
		source "/usr/local/lib/nadeshiko/bahelite/bahelite.sh";;
	*)
		source "$mypath/lib/bahelite/bahelite.sh";;
esac
prepare_cachedir 'nadeshiko'
start_log
set_libdir 'nadeshiko'
set_modulesdir 'nadeshiko'
set_exampleconfdir 'nadeshiko'
prepare_confdir 'nadeshiko'
place_rc_and_examplerc

declare -r version="2.2.11"
info "Nadeshiko-do-postponed v$version" >>"$LOG"
declare -r rcfile_minver='2.0'
declare -r postponed_commands="$CACHEDIR/postponed_commands"
declare -r postponed_commands_dir="$CACHEDIR/postponed_commands_dir"
declare -r failed_jobs_dir="$postponed_commands_dir/failed"

read_rcfile "$rcfile_minver"
[ "${taskset_cpulist:-}" ] && {
	[[ "$taskset_cpulist" =~ ^[0-9,-]+$ ]] \
		|| err 'Invalid CPU list for taskset.'
	REQUIRED_UTILS+=(taskset)  # (util-linux)
	taskset_cmd="taskset --cpu-list $taskset_cpulist"
}
[ "${niceness_level:-}" ] && {
	[[ "$niceness_level" =~ ^-?[0-9]{1,2}$ ]] \
		|| err 'Invalid level for nice.'
	REQUIRED_UTILS+=(nice)  # (coreutils)
	nice_cmd="nice -n $niceness_level"
}
check_required_utils
declare -r xml=$(which xmlstarlet)  # for lib/xml_and_python_functions.sh

single_process_check
pgrep -u $USER -af "bash.*nadeshiko.sh" &>/dev/null  \
	&& err 'Cannot run at the same time with Nadeshiko.'
pgrep -u $USER -af "bash.*nadeshiko-mpv.sh" &>/dev/null  \
	&& err 'Cannot run at the same time with Nadeshiko-mpv.'

cd "$TMPDIR"

 # Process $postponed_commands as a file with multiple commands (old format)
#  There’s a weird bug when this was done a simpler way – gathering path
#    to executable and args and then launching "${comcom[@]}", when an empty
#    line is read. Somehow, parts of ffmpeg output still got to the terminal,
#    and after Nadeshiko was called once, the next line read from postponed
#    was Time2 or the line with source video.
#  Avoiding this bug by assembling all commands first and running them later.
process_file() {
	declare -g failed_jobs
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
			[ -d "$failed_jobs_dir" ] || mkdir "$failed_jobs_dir"
			if set_last_log_path 'nadeshiko'; then
				mv "$LAST_LOG_PATH" "$failed_jobs_dir"
			else
				warn "Cannot get last log."
			fi
			let ++failed_jobs
		}
	done

	rm -f "$postponed_commands"
	return 0
}


 # Process $postponed_commands_dir (new format)
#
process_dir() {
	declare -g failed_jobs
	local last_log
	while IFS= read -r -d '' jobfile; do
		if ${nice_cmd:-} ${taskset_cmd:-} "$jobfile";  then
			rm "$jobfile"
		else
			[ -d "$failed_jobs_dir" ] || mkdir "$failed_jobs_dir"
			if set_last_log_path 'nadeshiko'; then
				mv "$LAST_LOG_PATH" "$failed_jobs_dir"
				mv "$jobfile" "$failed_jobs_dir"
			else
				warn "Cannot get last log."
			fi
			let ++failed_jobs
		fi
	done < <( find "$postponed_commands_dir" -maxdepth 1 -type f -print0 )
	return 0
}


run_jobs() {
	#  Finishing tasks from the single file, which is deprecated.
	[ -f "$postponed_commands" ] && process_file
	#  Doing tasks from the directory, the new way.
	[ -d "$postponed_commands_dir" ] && process_dir
	return 0
}


 # Return true, if there are jobs, return false, if there are no jobs to do.
#
collect_jobs() {
	if [ -f "$postponed_commands" ]; then
		if [ "$(<"$postponed_commands")" ]; then
			#  count jobs
			jobs_in_file=$(grep -cF 'nadeshiko.sh' "$postponed_commands") ||:
			[[ "$jobs_in_file" =~ ^[0-9]+$ ]] \
				|| err 'Couldn’t get the count of jobs in the file.'
		fi
	fi

	if [ -d "$postponed_commands_dir" ]; then
		if [ "$(ls -A "$postponed_commands_dir")" ]; then
			while IFS='' read -r -d ''; do
				let ++jobs_in_dir
			done < <( find "$postponed_commands_dir" -maxdepth 1 \
			               -type f -print0 )
		fi
	fi

	if [ -d "$failed_jobs_dir" ]; then
		if [ "$(ls -A "$failed_jobs_dir")" ]; then
			while IFS='' read -r -d ''; do
				let ++failed_jobs
			done < <( find "$failed_jobs_dir" -maxdepth 1 -iname "*.sh"  \
			               -type f -print0 )
		fi
	fi

	jobs_to_run=$(( jobs_in_file + jobs_in_dir ))
	total_jobs=$(( jobs_in_file + jobs_in_dir + failed_jobs ))
	info "Job count
	      ─────────────────
	      in the file: $jobs_in_file
	      in the directory: $jobs_in_dir
	          total for the launch: $jobs_to_run

	      in failed: $failed_jobs"
	return 0
}



jobs_in_file=0
jobs_in_dir=0
jobs_to_run=0
failed_jobs=0
total_jobs=0

if [ -v DISPLAY ]; then
	. "$MODULESDIR/nadeshiko-do-postponed_dialogues_${dialog:=gtk}.sh"
	collect_jobs
	show_dialogue_launch_jobs "$jobs_to_run" "$failed_jobs"
	IFS=$'\n' read -r -d ''  resp_action  < <(echo -e "$dialog_output\0")
	if [ "$resp_action" = 'run_jobs' ]; then
		run_jobs
		# show_dialogue_jobs_result
	else
		exit 0
	fi
else
	run_jobs
fi


exit 0
