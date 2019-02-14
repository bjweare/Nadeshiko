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
	versioning
	misc
)
. "$(dirname "$(realpath --logical "$0")")/lib/bahelite/bahelite.sh"
prepare_cachedir 'nadeshiko'
start_log
set_libdir 'nadeshiko'
set_modulesdir 'nadeshiko'
set_exampleconfdir 'nadeshiko'
prepare_confdir 'nadeshiko'

declare -r version="2.2.3"
declare -r rcfile_minver='2.0'
declare -r postponed_commands="$CACHEDIR/postponed_commands"
declare -r postponed_commands_dir="$CACHEDIR/postponed_commands_dir"
declare -r failed_jobs_dir="$postponed_commands_dir/failed"

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
	declare -g failed_jobs_count
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
			let ++failed_jobs_count
		}
	done

	rm -f "$postponed_commands"
	return 0
}


 # Process $postponed_commands_dir (new format)
#
process_dir() {
	declare -g failed_jobs_count
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
			let ++failed_jobs_count
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
are_there_any_jobs() {
	declare -g file_jobs_count  dir_jobs_count  total_jobs
	file_jobs_count=0
	dir_jobs_count=0
	total_jobs=0
	local jobs_in_file=t  jobs_in_dir=t
	if [ -f "$postponed_commands" ]; then
		if [ "$(<"$postponed_commands")" ]; then
			#  count jobs
			file_jobs_count=$(grep -cF 'nadeshiko.sh' "$postponed_commands") ||:
			[[ "$file_jobs_count" =~ ^[0-9]+$ ]] \
				|| err 'Couldn’t get the count of jobs in the file.'
		else
			unset jobs_in_file
		fi
	else
		unset jobs_in_file
	fi

	if [ -d "$postponed_commands_dir" ]; then
		if [ "$(ls -A "$postponed_commands_dir")" ]; then
			while IFS='' read -r -d ''; do
				let ++dir_jobs_count
			done < <( find "$postponed_commands_dir" -type f -print0 )
		else
			unset jobs_in_dir
		fi
	else
		unset jobs_in_dir
	fi

	total_jobs=$(( file_jobs_count + dir_jobs_count ))
	info "Jobs in file: $file_jobs_count
	      Jobs in directory: $dir_jobs_count
	      Total jobs: $total_jobs"
	((total_jobs > 0)) \
		&& return 0 \
		|| return 1
}



failed_jobs_count=0

if [ -v DISPLAY ]; then
	. "$MODULESDIR/nadeshiko-do-postponed_dialogues_${dialog:=gtk}.sh"
	if are_there_any_jobs; then
		info "There are jobs to run, asking to confirm."
	 	show_dialogue_launch_jobs "$total_jobs"
	 	IFS=$'\n' read -r -d ''  resp_action  < <(echo -e "$dialog_output\0")
	 	if [ "$resp_action" = 'run_jobs' ]; then
			run_jobs
			# show_dialogue_jobs_result
		else
			abort 'Cancelled.'
		fi
	else
		show_dialogue_no_jobs
	fi
else
	run_jobs
fi


exit 0
