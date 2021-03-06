#! /usr/bin/env bash

#  nadeshiko-do-postponed.sh
#  Wrapper for Nadeshiko to encode postponed files.
#  © deterenkelt 2018–2020
#
#  For licence see nadeshiko.sh


set -feEuT
MY_BUNCH_NAME='nadeshiko'
BAHELITE_LOAD_MODULES=(
	libdir
	modulesdir
	logging:use_cachedir
	rcfile:use_metaconf:use_defconf
	messages_to_desktop
	misc
)
mypath=$(dirname "$(realpath --logical "$0")")
case "$mypath" in
	'/usr/bin'|'/usr/local/bin')
		source "${mypath%/bin}/lib/nadeshiko/bahelite/bahelite.sh";;
	*)
		source "$mypath/lib/bahelite/bahelite.sh";;
esac

place_examplerc 'nadeshiko-do-postponed.10_main.rc.sh'

declare -r version="2.3.9"

declare -r postponed_commands_dir="$CACHEDIR/postponed_commands_dir"
declare -r failed_jobs_dir="$postponed_commands_dir/failed"



show_version() {
	cat <<-EOF
	nadeshiko-do-postponed.sh $version
	© deterenkelt 2018–2019.
	Licence: GNU GPL ver. 3  <http://gnu.org/licenses/gpl.html>
	This is free software: you are free to change and redistribute it.
	There is no warranty, to the extent permitted by law.
	EOF
	return 0
}


on_exit() {
	#  Make sure, that we move the failed job files to $failed_jobs_dir
	#  if the program is interrupted.
	[ -v job_logdir  -a  -d "${job_logdir:-}" ]  \
		&& move_job_to_failed "$jobfile" "$job_logdir"
	return 0
}


move_job_to_failed() {
	local  jobfile="$1"
	local  job_logdir="$2"

	[ -d "$failed_jobs_dir" ] || mkdir "$failed_jobs_dir"
	mv "$jobfile"    "$failed_jobs_dir/"
	#  When user takes the .sh job from the “failed” subdirectory, its log
	#  folder will remain there. It should be preventively removed.
	rm -rf "$failed_jobs_dir/${job_logdir##*/}"
	mv "$job_logdir" "$failed_jobs_dir/"

	return 0
}


post_read_rcfile() {
	declare -g  taskset_cpulist
	declare -g  taskset_cmd
	declare -g  niceness_level
	declare -g  nice_cmd
	declare -g  nadeshiko_desktop_notifications

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
	if [[ "$nadeshiko_desktop_notifications" =~ ^(none|error|all)$ ]]; then
		case "$nadeshiko_desktop_notifications" in
			none)
				nadeshiko_desktop_notifications=0;;
			error)
				nadeshiko_desktop_notifications=1;;
			all)
				nadeshiko_desktop_notifications=3;;
		esac
	else
		redmsg "nadeshiko_desktop_notifications parameter should be set
		        to one of: none, error, all."
		err "Invalid value for desktop notifications in the config."
	fi

	return 0
}


 # Process $postponed_commands_dir (new format)
#
process_dir() {
	declare -g  processed_jobs
	declare -g  failed_jobs
	declare -g  completed_jobs

	local  msg
	local  no_alljobs_message_to_desktop

	while IFS= read -r -d '' jobfile; do
		if [[ "${jobfile##*/}" =~ \.(.{8})\.sh$ ]]; then
			job_id="${BASH_REMATCH[1]}"
			job_logdir="$postponed_commands_dir/$job_id.log"
			mkdir "$job_logdir"
		else
			redmsg "Invalid job id in file
			        ${jobfile##*/}"
			err 'Cannot determine job ID.'
		fi

		msg="Running job "
		msg+="${__bri}${__g}$((processed_jobs+1))${__s}"
		msg+="/$jobs_in_dir; "
		msg+="ID ${__bri}$job_id${__s}…  "
		infon "$msg"

		: ${nadeshiko_verbosity_level:=30$nadeshiko_desktop_notifications}

		if	env  \
				LOGDIR="$job_logdir"  \
				VERBOSITY_LEVEL=$nadeshiko_verbosity_level  \
				MSG_INDENTATION_LEVEL="$MSG_INDENTATION_LEVEL"  \
				${nice_cmd:-} ${taskset_cmd:-} "$jobfile"

		then
			let '++completed_jobs,  1'
			echo -e "${__g}${__bri}Complete${__s} "
			rm -rf "$jobfile" "$job_logdir" "$failed_jobs_dir/${job_logdir##*/}"

		else
			echo -e "${__r}${__bri}Fail.${__s}"
			move_job_to_failed "$jobfile" "$job_logdir"
			let '++failed_jobs,  1'
			#  Stop running if the shell is in interactive mode.
			#  (doesn’t work: $- may be unset even in an actually interactive
			#   shell, and checking the output of “tty” command will depend
			#   on the terminal in question.
			# [[ "$-" =~ .*i.* ]] && err ''
		fi
		let '++processed_jobs,  1'

	done < <( find "$postponed_commands_dir"  -maxdepth 1  -type f  -print0 )

	rmdir "$failed_jobs_dir" 2>/dev/null || true

	(( processed_jobs > 0 )) && {
		(( processed_jobs == 1  &&  nadeshiko_desktop_notifications == 3 ))  \
			&& no_alljobs_message_to_desktop=t
		if [ -v no_alljobs_message_to_desktop ]; then
			info 'All jobs processed.'
		else
			info-ns 'All jobs processed.'
		fi
	}

	info "Encoded: $completed_jobs
	      Failed:  $failed_jobs
	      Total:   $total_jobs"
	return 0
}


run_jobs() {
	#  Doing tasks from the directory, the new way.
	[ -d "$postponed_commands_dir" ] && process_dir
	return 0
}


 # Counts jobs and sets counters.
#
collect_jobs() {
	if [ -d "$postponed_commands_dir" ]; then
		if [ "$(ls -A "$postponed_commands_dir")" ]; then
			while IFS='' read -r -d ''; do
				let '++jobs_in_dir,  1'
			done < <( find "$postponed_commands_dir" -maxdepth 1 \
			               -type f -print0 )
		fi
	fi

	if [ -d "$failed_jobs_dir" ]; then
		if [ "$(ls -A "$failed_jobs_dir")" ]; then
			while IFS='' read -r -d ''; do
				let '++failed_jobs,  1'
			done < <( find "$failed_jobs_dir" -maxdepth 1 -iname "*.sh"  \
			               -type f -print0 )
		fi
	fi

	jobs_to_run=$jobs_in_dir
	total_jobs=$(( jobs_in_dir + failed_jobs ))
	info "Job count
	      ─────────────────
	      to run: $jobs_in_dir
	      in failed: $failed_jobs"
	return 0
}



info "Nadeshiko-do-postponed v$version"
cd "$TMPDIR"
post_read_rcfile
if (( $# == 0 )); then
	: "All is OK, proceeding to execution."
elif (( $# == 1 )) && [[ "$1" =~ ^(-v|--version)$ ]]; then
	show_version
	exit 0
else
	err "Wrong arguments: $@"
fi

check_required_utils
declare -r xml='xmlstarlet'   # for lib/xml_and_python_functions.sh

print_verbosity_level
single_process_check
pgrep -u $USER -af "bash.*nadeshiko.sh" &>/dev/null  \
	&& err 'Cannot run at the same time with Nadeshiko.'
pgrep -u $USER -af "bash.*nadeshiko-mpv.sh" &>/dev/null  \
	&& err 'Cannot run at the same time with Nadeshiko-mpv.'

jobs_in_dir=0
jobs_to_run=0
total_jobs=0
completed_jobs=0
failed_jobs=0
processed_jobs=0

if [ -v DISPLAY ]; then
	. "$MODULESDIR/nadeshiko-do-postponed/dialogues_${dialog:=gtk}.sh"
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
	collect_jobs
	run_jobs
fi


exit 0