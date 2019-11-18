#  Should be sourced.

#  04_encoding.sh
#  Nadeshiko-mpv module where the encoding backend is called (or the encoding
#  is postponed and stored as a job file for Nadeshiko-do-postponed).
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko-mpv.sh


encode() {
	local  audio
	local  subs
	local  nadeshiko_retval
	local  command
	local  postponed_job_file
	local  str
	local  first_line_in_postponed_command=t

	check_needed_vars

	if [ -v ffmpeg_ext_audio ]; then
		audio="audio=$ffmpeg_ext_audio"
	elif [ -v ffmpeg_audio_tr_id ]; then
		audio="audio:$ffmpeg_audio_tr_id"
	else
		audio=noaudio
	fi

	 # Never rely on “sub_visibility” property, as it is on by default:
	#  even when there’s no subtitles at all.
	if [ -v ffmpeg_ext_subs ]; then
		subs="subs=$ffmpeg_ext_subs"
	elif [ -v ffmpeg_subs_tr_id ]; then
		subs="subs:$ffmpeg_subs_tr_id"
	else
		subs='nosubs'
	fi

	if [ -e "/proc/${mpv_pid:-not exists}" ]; then
		send_command  show-text 'Encoding' '2000'
	else
		: warn-ns "Not sending anything to mpv: it was closed."
	fi


	#  The existence of the default preset is not obligatory.
	if     [ "${nadeshiko_preset:-}" = 'nadeshiko.rc.sh' ]  \
	    && [ ! -r "$CONFDIR/nadeshiko.rc.sh" ]
    then
	    unset nadeshiko_preset
	fi

	 # “postpone” passed to nadeshiko-mpv.sh forks the process in a paused
	#    state in the background. When nadeshiko.sh (not …-mpv.sh!) is called
	#    with a single parameter “unpause”, it unfreezes the processes
	#    one by one and then quits.
	#  This allows to free the watching from humming/heating and probably,
	#    even glitchy playback, if you attempt to continue watching after
	#    firing up the encode, especially, if it’s the 2nd, the 3rd or the 15th.
	#  $max_size is allowed to be empty for quick_run mode (max_size then
	#    just sourced from the quick_run_preset or from the defconf settings).
	#
	nadeshiko_command=(
		"$MYDIR/nadeshiko.sh"  "${time1[ts]}"
		                       "${time2[ts]}"
		                       "$path"
		                       "$audio"
		                       "$subs"
		                       ${max_size:-}
		                       ${crop:+crop=$crop}
		                       "${screenshot_directory:-$working_directory}"
		                       ${fname_pfx:+"fname_pfx=$fname_pfx"}
		                       ${scene_complexity:+force_scene_complexity=$scene_complexity}
		                       "${nadeshiko_preset[@]}"
		                       do_not_report_ffmpeg_progress_to_console
	)
	if [ -v postpone ]; then
		[ -d "$postponed_commands_dir" ] || mkdir "$postponed_commands_dir"
		postponed_job_file="$postponed_commands_dir"
		postponed_job_file+="/$(
			mktemp -u "${path##*/} ${time1[ts]}–${time2[ts]}.XXXXXXXX"
		).sh"
		cat <<-EOF >"$postponed_job_file"
		#! /usr/bin/env bash

		#  Nadeshiko-mpv postponed job file
		#  ${postponed_job_file##*/}
		#  This file is to be run with nadeshiko-do-postponed.sh


		EOF
		chmod +x "$postponed_job_file"
		for str in "${nadeshiko_command[@]}"; do
			if [ -v first_line_in_postponed_command ]; then
				printf '%q  \\\n\t\\\n' "$str" >>"$postponed_job_file"
				unset first_line_in_postponed_command
			else
				printf '\t%q  \\\n' "$str" >>"$postponed_job_file"
			fi
		done
		echo >>"$postponed_job_file"
		rm "$data_file"
		if [ -e "/proc/${mpv_pid:-not exists}" ]; then
			send_command  show-text \
			              "Command to encode saved for later."  \
			              '2000'
		fi
		exit 0
	else
		info 'Running Nadeshiko'
		headermsg 'Nadeshiko log'
		errexit_off

		env  \
			VERBOSITY_LEVEL=030  \
			"${nadeshiko_command[@]}"

		nadeshiko_retval=$?
		errexit_on

		footermsg 'End of Nadeshiko log'
		rm "$data_file"
		if [ -e "/proc/${mpv_pid:-not exists}" ]; then
			if [ $nadeshiko_retval -eq 0 ]; then
				send_command  show-text 'Encoding done.' '2000'
				info-ns 'Encoding done.'
			else
				send_command  show-text 'Failed to encode.' '3000'
				err 'Failed to encode.'
			fi
		else
			: warn-ns "Not sending anything to mpv: it was closed."
		fi
	fi
	return 0
}


return 0