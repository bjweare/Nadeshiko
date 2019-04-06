#  Should be sourced.

#  nadeshiko-mpv_stage01_set_times.sh
#  Nadeshiko-mpv module that queries the running mpv and gathers current
#  options from the player, among the other, the timestamp of the position
#  in the video.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko-mpv.sh


write_var_to_datafile() {
	local varname="$1" varval="$2"  var
	[ "$varval" = '--only-export' ] || {
		info "Setting $varname and appending it to ${data_file##*/}."
		declare -g $varname="$varval"
	}
	sed -ri "/^(declare -[a-zA-Z]+ |)$varname=/d" "$data_file"
	#  Human-readable times in the postponed jobs
	#  NB this code relies upon bash-4.4 “@A” operator. It appeared only
	#  recently, and the nuances described below may change in the future.
	#  1. @A operator resolves the nameref – the original variable name
	#     is printed.
	#  2. [@] is necessary to restore arrays, but the regular variables
	#     accept it too (even integers!), which allows to avoid making
	#     “[@]” placed conditionally.
	declare -n var=$varname
	echo "${var[@]@A}" >> "$data_file"
	return 0
}


del_var_from_datafile() {
	local varname="$1"
	unset $varname
	info "Deleting $varname from ${data_file##*/}."
	sed -ri "/^(declare -[a-zA-Z]+ |)$varname=/d" "$data_file"
	return 0
}


populate_data_file() {
	declare -g  ffmpeg_ext_subs  ffmpeg_subs_tr_id  ffmpeg_audio_tr_id
	local i tr_type tr_is_selected tr_id ff_index \
	      tr_is_external external_filename
	#  NB path must come after working directory!
	#  path must be a valid file, but path *may be* relative
	#  to $working_directory, thus the latter becomes a part of the path’s
	#  “good value” test.
	#
	#  Should be done earlier, see below.
	# write_var_to_datafile mpv_socket "$mpv_socket"
	get_props working-directory \
	          screenshot-directory \
	          path \
	          mute \
	          sub-visibility \
	          track-list \
	          track-list/count \
	          volume
	write_var_to_datafile working_directory "$working_directory"
	write_var_to_datafile screenshot_directory "$screenshot_directory"
	if [ -e "$path" ]; then
		write_var_to_datafile path "$path"
	elif [ -e "$working_directory/$path" ]; then
		write_var_to_datafile path "$working_directory/$path"
	fi
	write_var_to_datafile mute $mute
	write_var_to_datafile sub_visibility $sub_visibility

	#  Subtitle and audio tracks are either an index of an internal stream
	#  or a path to an external file.
	for ((i=0; i<track_list_count; i++)); do
		IFS=$'\n' read -d '' tr_type \
		                     tr_is_selected \
		                     tr_id  ff_index \
		                     tr_is_external  external_filename \
			< <( echo "$track_list" \
			     | jq -r ".[$i].type, \
			              .[$i].selected,  \
			              .[$i].id,  .[$i].\"ff-index\", \
			              .[$i].external,  .[$i].\"external-filename\""; \
			     echo -en '\0'
			   )
		echo
		info "Track $i
		      Type: $tr_type
		      Selected: $tr_is_selected
		      ID: $tr_id
		      FFmpeg index: $ff_index
		      External: $tr_is_external
		      External filename: $external_filename"
		milinc
		[ "$tr_is_selected" = true ] && {
			#  ffmpeg_subs_tr_id  and  ffmpeg_audio_tr_id  are to become
			#  “subs” and “audio” parameters for Nadeshiko, thus, they must be
			#  set only subtitles are enabled and audio is on.
			if [ "$tr_type" = sub  -a  -v sub_visibility_true ]; then
				case "$tr_is_external" in
					true)
						if [ -f "$external_filename" ]; then
							ffmpeg_ext_subs="$external_filename"
						elif [ -f "$working_directory/$external_filename" ]; then
							ffmpeg_ext_subs="$working_directory/$external_filename"
						else
							ffmpeg_ext_subs="$FUNCNAME: mpv’s “$external_filename” is not a valid path."
						fi
						write_var_to_datafile ffmpeg_ext_subs "$ffmpeg_ext_subs"
						;;
					false)
						# man mpv says:
						# “Note that ff-index can be potentially wrong if a
						#    demuxer other than libavformat (--demuxer=lavf)
						#    is used. For mkv files, the index will usually
						#    match even if the default (builtin) demuxer is
						#    used, but there is no hard guarantee.”
						# Note the difference between tr_id and ff_index:
						#   - ‘ff_index’ is the number of a *stream* by order,
						#     this includes all video, audio, subtitle streams
						#     and also fonts. ffmpeg -map would use syntax
						#     0:<stream_id> to refer to the stream.
						#   - ‘tr_id’ is the number of this stream among
						#     the other streams of *this same type*.
						#     ffmpeg -map uses syntax 0:s:<subtitle_stream_id>
						#     for these – that’s exactly what we need.
						#     It’s necessary to decrement it by one, as mpv
						#     counts them from 1 and ffmpeg – from 0.
						ffmpeg_subs_tr_id=$((  tr_id - 1  ))
						write_var_to_datafile ffmpeg_subs_tr_id "$ffmpeg_subs_tr_id"
						;;
				esac
				#  ffmpeg_subtitles now contains either a track id,
				#  an absolute path or an error message (Nadeshiko handles all).
			elif [ "$tr_type" = audio   -a  ! -v mute_true ]; then
				case "$tr_is_external" in
					true)
						err 'Cannot add external audio track: not supported yet.'
						;;
					false)
						#  See the note at the similar place above.
						ffmpeg_audio_tr_id=$((  tr_id - 1  ))
						write_var_to_datafile ffmpeg_audio_tr_id "$ffmpeg_audio_tr_id"
						;;
				esac
			fi
		}
		mildec
	done

	cat "$data_file"
	return 0
}


put_time() {
	local mute_text subvis_text
	get_prop  time-pos
	if [ ! -v time1 -o -v time2 ]; then
		new_time_array  time1  "${time_pos%???}"
		write_var_to_datafile  time1  --only-export
		get_props sub-visibility mute
		[ -v sub_visibility_true ] \
			&& subvis_text='Subs: ON' \
			|| subvis_text='Subs: OFF'
		[ -v mute_true ] \
			&& mute_text='Sound: OFF' \
			|| mute_text='Sound: ON'
		send_command show-text "Time1 set\n$subvis_text\n$mute_text" "3000"
		unset time2
		del_var_from_datafile time2

	elif [ -v time1 -a ! -v time2 ]; then
		new_time_array  time2  "${time_pos%???}"
		write_var_to_datafile  time2  --only-export
		populate_data_file
		[ -v sub_visibility_true ] \
			&& subvis_text='Subs: ON' \
			|| subvis_text='Subs: OFF'
		[ -v mute_true ] \
			&& mute_text='Sound: OFF' \
			|| mute_text='Sound: ON'
		send_command show-text "Time2 set\n$subvis_text\n$mute_text" "3000"
	fi
	return 0
}


arrange_times() {
	check_needed_vars
	declare -A time_buf=()
	[ "${time1[ts]}" = "${time2[ts]}" ] && err "Time1 and Time2 are the same."
	[ "${time1[total_ms]}" -gt "${time2[total_ms]}" ] && {
		new_time_array  time_buf "${time1[ts]}"
		new_time_array  time1 "${time2[ts]}"
		new_time_array  time2 "${time_buf[ts]}"
		write_var_to_datafile  time1 --only-export
		write_var_to_datafile  time2 --only-export
	}
	return 0
}


return 0