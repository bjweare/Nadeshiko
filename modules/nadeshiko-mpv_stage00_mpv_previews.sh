#  Should be sourced.

#  nadeshiko-mpv_stage00_mpv_previews.sh
#  Nadeshiko-mpv module for running a separate mpv with a preview of the clip
#  to be encoded and the encoded file.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko-mpv.sh


pause_and_leave_fullscreen() {
	local  rewind_to_time_pos
	#  Calculating time-pos to rewind to later.
	#  Doing it beforehand to avoid lags on socket connection.
	get_props 'time-pos' 'fullscreen'
	rewind_to_time_pos=${time_pos%.*}
	let "rewind_to_time_pos-=2 ,1"
	(( rewind_to_time_pos < 0 )) && rewind_to_time_pos=0
	set_prop 'pause' 'yes'

	if	(
			[    "${FUNCNAME[1]}" = play_preview ]  \
			|| [ "${FUNCNAME[1]}" = choose_crop_settings ]  \
			|| [ "${FUNCNAME[1]}" = play_encoded_file  -a  ! -v postpone ]
		) \
		&& [ -v fullscreen_true ]
	then
		#  If the player was in fullscreen, return it back to windowed mode,
		#  or the preview will be playing somewhere in the background.
		#
		#  When in fullscreen mode, sleep for 1.7 seconds, so that
		#  before we turn off fullscreen to show the encoded file,
		#  the user would notice, that the encoding is done, and would
		#  expect to see another file.
		#
		#  Sleeping in paused state while “Encoding is done” is shown.
		[ "$(type -t sleep)" = file ] \
			&& sleep 1.700 \
			|| sleep 2
		set_prop 'fullscreen' 'no'
		#  Rewind the file two seconds back, so that continuing wouldn’t
		#    be from an abrupt moment for the user.
		#  This option is a little unsettling, so it is disabled by default.
		[ -v rewind_back_on_leaving_fullscreen ] \
			&& set_prop 'time-pos' "$rewind_to_time_pos"
	fi
	#  When the encoding is postponed,
	#  pause only for the time notification is shown, and then unpause.
	[ "${FUNCNAME[1]}" = play_encoded_file  -a  -v postpone ] && {
		#  Sleeping in paused state while “Command to encode saved for later.”
		#  is shown. The notification is shown for exectly two seconds, and
		#  due to a small lag it will probably take a bit longer, so sleeping
		#  for two full seconds here.
		sleep 2
		set_prop 'pause' 'no'
		#  We didn’t go off of fullscreen, so no need to rewind.
	}
	return 0
}


play_preview() {
	[ -v show_preview ] || return 0
	#  Avoiding the bug with old .ts files (MPEG transport stream), in which
	#  positioning doesn’t work because of an error:
	#  [ffmpeg/video] h264: reference picture missing during reorder
	#  mpv with a preview would hang without even showing a window.
	if	[[ "$path" =~ \.(TS|ts) ]]  \
		&& [[ "$(file -L -b "$path")" = MPEG\ transport\ stream ]]
	then
		warn-ns 'Skipping preview: positioning in .ts files is bugged.'
		sleep  3  # For the user to have time to read the message.
		return 0
	fi
	local  temp_sock="$(mktemp -u)"  sub_file  sid  audio_file  aid  vf_crop
	check_needed_vars  'sub-file'
	pause_and_leave_fullscreen
	#  --ff-sid and --ff-aid, that take track numbers in FFmpeg order,
	#  i.e. starting from zero within their type, do not work with
	#  certain files.
	[ "$sub_visibility" = yes ] && {
		[ -v ffmpeg_ext_subs ]  \
			&& sub_file=(--sub-file "$ffmpeg_ext_subs")  # sic!
		[ -v ffmpeg_subs_tr_id ]  \
			&& sid="--sid=$(( ffmpeg_subs_tr_id +1 ))"
	}
	[ -v mute ] || {
		[ -v ffmpeg_ext_audio ]  \
			&& audio_file=(--audio-file "$ffmpeg_ext_audio")  # sic!
		[ -v ffmpeg_audio_tr_id ]  \
			&& aid="--aid=$(( ffmpeg_audio_tr_id +1 ))"
	}
	[ -v crop ] && vf_crop="--vf=crop=$crop"

	info 'Playing preview of the clip to be cut.'
	$mpv --x11-name mpv-nadeshiko-preview   \
	     --title "Preview – $MY_DISPLAY_NAME"  \
	     --input-ipc-server="$temp_sock"  \
	     --pause=no  \
	     --start="${time1[ts]}"  \
	     --ab-loop-a="${time1[ts]}" --ab-loop-b="${time2[ts]}"  \
	     --mute=$mute  \
		     ${aid:-}  \
		     ${audio_file:-}  \
		     --volume=$volume  \
	     --sub-visibility=$sub_visibility  \
	         "${sub_file[@]}"  \
	         ${sid:-}  \
	     ${vf_crop:-}  \
	     --osd-msg1="Preview"  \
	     "$path"
	rm "$temp_sock"
	return 0
}


play_encoded_file() {
	[ -v show_encoded_file ] || return 0
	(( $(get_bahelite_verbosity logging) < 3 ))  && {
		info-ns 'Not showing encoded file: logs are disabled.'
		return 0
	}
	local  last_file  temp_sock
	check_needed_vars
	last_file=$(
		sed -rn '/Encoded successfully/ { n
		                                  s/[[:cntrl:]]\[[0-9]{1,3}[mKG]//g
		                                  s/^\s*\* //p
		                                }'  \
		    "$LOGPATH"
	)
	info "Path to the encoded file:
	      $last_file"
	[ -r "${screenshot_directory:-$working_directory}/$last_file" ] || {
		warn-ns 'Cannot find the encoded file'
		return 0   # not that critical for an error.
	}

	[ -e "/proc/${mpv_pid:-not exists}" ] && {
		pause_and_leave_fullscreen
		temp_sock="$(mktemp -u)"
		info 'Playing the encoded file'
		#  Setting --screenshot-directory, because otherwise screenshots
		#  taken from that video would fall into $datadir, and it’s not
		#  obvious to seek for them there.
		$mpv --x11-name mpv-nadeshiko-preview  \
		     --title "Encoded file – $MY_DISPLAY_NAME"  \
		     --input-ipc-server="$temp_sock"  \
		     --pause=no  \
		     --loop-file=inf  \
		     --mute=no  \
		     --volume=$volume  \
		     --sub-visibility=yes  \
		     --osd-msg1="Encoded file"  \
		     --screenshot-directory="${screenshot_directory:-$working_directory}"  \
		     "${screenshot_directory:-$working_directory}/$last_file"
		rm -f "$temp_sock"
	}
	return 0
}


return 0