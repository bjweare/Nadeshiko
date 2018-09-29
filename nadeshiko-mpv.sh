#! /usr/bin/env bash

#  nadeshiko-mpv.sh
#  Wrapper for Nadeshiko to provide IPC with mpv.
#  deterenkelt © 2018
#
#  For licence see nadeshiko.sh

set -feEuT
. "$(dirname "$0")/lib/bahelite/bahelite.sh"
prepare_cachedir 'nadeshiko'
start_log
set_libdir 'nadeshiko'
. "$LIBDIR/mpv_ipc.sh"
set_modulesdir 'nadeshiko'
set +f
for module in "$MODULESDIR"/nadeshiko-mpv_*.sh ; do
	. "$module" || err "Couldn’t source module $module."
done
set -f
set_exampleconfdir 'nadeshiko'
prepare_confdir 'nadeshiko'

declare -r version="2.1.1"
declare -r rcfile_minver='2.0'
RCFILE_BOOLEAN_VARS=(
	show_preview
	show_encoded_file
	show_name_setting_dialog
)
#  Defining it here, so that the definition in RC would be shorter
#  and didn’t confuse users with “declare -gA …”.
declare -A mpv_sockets
declare -r datadir="$CACHEDIR/nadeshiko-mpv_data"
declare -r postponed_commands="$CACHEDIR/postponed_commands"

our_processes=$(pgrep -u $USER -afx "bash $0" -s 0)
total_processes=$(pgrep -u $USER -afx "bash $0")
our_processes_count=$(echo "$our_processes" | wc -l)
total_processes_count=$(echo "$total_processes" | wc -l)
(( our_processes_count < total_processes_count )) && {
	warn "Processes: our: $our_processes_count, total: $total_processes_count.
	      Our processes are:
	      $our_processes
	      Our and foreign processes are:
	      $total_processes"
	err 'Still running.'
}


on_error() {
	# Wipe the data directory, so that after a stop caused by an error
	# we wouldn’t read the old data, but tried to create new ones.
	# The data per se probably won’t break the script, but those data
	# could be just stale.
	touch "$datadir/wipe_me"
}
[ -d "$datadir" ] || mkdir "$datadir"
cd "$datadir"
if [ -e wipe_me ]; then
	set +f
	rm -rf ./*
	set -f
else
	# Delete files older than one hour.
	find -type f -mmin +60  -delete
fi



show_help() {
	cat <<-EOF
	Usage:
	./nadeshiko-mpv.sh [postpone]

	This program automatically connects to an mpv socket (set the path to it
	in $rc_file). On the first run it sets Time1, on the second run –
	Time2 and goes further to preview, encode and playing the encoded file.

	“postpone”, the only possible and optional parameter, tells this script
	to not run Nadeshiko, and store the command calling her in a file
	named “postponed_commands”. Call nadeshiko-do-postponed.sh to read
	and execute those commands.

	Bind this script to a hotkey in the window manager – mpv itself
	doesn’t send any commands to it.
	EOF
}


show_version() {
	cat <<-EOF
	nadeshiko-mpv.sh $version
	© deterenkelt 2018.
	Licence GPLv3+: GNU GPL ver. 3  <http://gnu.org/licenses/gpl.html>
	This is free software: you are free to change and redistribute it.
	There is no warranty, to the extent permitted by law.
	EOF
}


post_read_rcfile() {
	dialog=${dialog,,}
	[ "$dialog" = xdialog ] && dialog="Xdialog"
	return 0
}


write_var_to_datafile() {
	local varname="$1" varval="$2"
	info "Setting $varname and appending it to ${data_file##*/}."
	declare -g $varname="$varval"
	sed -ri "/^$varname=/d" "$data_file"
	printf "$varname=%q\n" "$varval" >> "$data_file"
	return 0
}


del_var_from_datafile() {
	local varname="$1"
	unset $varname
	info "Deleting $varname from ${data_file##*/}."
	sed -ri "/^$varname=/d" "$data_file"
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
	write_var_to_datafile mpv_socket "$mpv_socket"
	get_props working-directory \
	          screenshot-directory \
	          path \
	          mute \
	          sub-visibility \
	          track-list \
	          track-list/count \
	    || exit $?
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
		info "Track $i
		      Type: $tr_type
		      Selected: $tr_is_selected
		      ID: $tr_id
		      FFmpeg index: $ff_index
		      External: $tr_is_external
		      External filename: $external_filename"
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
						err 'External audio tracks aren’t supported yet.
						     Please post an issue on the project page to speed up the work!'
						;;
					false)
						#  See the note at the similar place above.
						ffmpeg_audio_tr_id=$((  tr_id - 1  ))
						write_var_to_datafile ffmpeg_audio_tr_id "$ffmpeg_audio_tr_id"
						;;
				esac
			fi
		}
	done

	cat "$data_file"
	return 0
}


 # This function verifies, that all the necessary variables
#  are set at the current stage. For that it has a list of
#  variable names for each caller function.
#
check_needed_vars() {
	declare -A vars_needed=(
		[arrange_times]='time1 time2'
		[play_preview]='time1 time2 mute sub_visibility'
		[pick_max_size]=''
		[encode]='time1 time2 mute sub_visibility max_size screenshot_directory working_directory'
		[play_encoded_file]='screenshot_directory working_directory'
	)
	for var in ${vars_needed[${FUNCNAME[1]}]}; do
		[ -v $var ] \
			|| err "func ${FUNCNAME[1]} needs variable “$var”, but it is not set."
	done
	return 0
}


put_time() {
	local mute_text subvis_text
	get_prop time-pos || exit $?
	time_pos=${time_pos%???}
	if [ ! -v time1 -o -v time2 ]; then
		write_var_to_datafile time1 "$time_pos"
		get_props sub-visibility mute || exit $?
		[ -v sub_visibility_true ] \
			&& subvis_text='Subs: ON' \
			|| subvis_text='Subs: OFF'
		[ -v mute_true ] \
			&& mute_text='Sound: OFF' \
			|| mute_text='Sound: ON'
		send_command show-text "Time1 set\n$subvis_text\n$mute_text" "3000" \
			|| exit $?
		unset time2
		del_var_from_datafile time2

	elif [ -v time1 -a ! -v time2 ]; then
		write_var_to_datafile time2 "$time_pos"
		populate_data_file
		[ -v sub_visibility_true ] \
			&& subvis_text='Subs: ON' \
			|| subvis_text='Subs: OFF'
		[ -v mute_true ] \
			&& mute_text='Sound: OFF' \
			|| mute_text='Sound: ON'
		send_command show-text "Time2 set\n$subvis_text\n$mute_text" "3000" \
			|| exit $?
	fi
	return 0
}


arrange_times() {
	check_needed_vars
	local time_buf
	[ "$time1" = "$time2" ] && err "Time1 and Time2 are the same."
	[ "${time1%.*}" -gt "${time2%.*}" ] && {
		time_buf="$time1"
		write_var_to_datafile time1 "$time2"
		write_var_to_datafile time2 "$time_buf"
	}
	return 0
}


unfullscreen_and_rewind() {
	local  rewind_to_time_pos
	#  Calculating time-pos to rewind to later.
	#  Doing it beforehand to avoid lags on socket connection.
	get_props 'time-pos' 'fullscreen'
	rewind_to_time_pos=${time_pos%.*}
	let "rewind_to_time_pos-=2 ,1"
	(( rewind_to_time_pos < 0 )) && rewind_to_time_pos=0
	set_prop 'pause' 'yes'

	if  (
			[ "${FUNCNAME[1]}" = play_preview ] \
			|| [ "${FUNCNAME[1]}" = play_encoded_file  -a  ! -v postpone ]
		) \
		&& [ -v fullscreen_true ]
	then
		#  If the player was in fullscreen, return it back to window mode,
		#  or the preview will be playing somewhere in the background.
		#
		#  When in fullscreen mode, sleep for 1.7 seconds, so that
		#  before we turn off fullscreen to show the encoded file,
		#  the use would notice, that the encoding is done, and would
		#  expect to see another file.
		#
		#  Sleeping in paused state while “Encoding is done” is shown.
		[ "$(type -t sleep)" = file ] \
			&& sleep 1.700 \
			|| sleep 2
		set_prop 'fullscreen' 'no'
		#  Rewind the file two seconds back, so that continuing wouldn’t
		#  be from an abrupt moment for the user.
		set_prop 'time-pos' "$rewind_to_time_pos"
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
	local  temp_sock="$(mktemp -u)"  sub_file  sid  aid
	check_needed_vars  'sub-file'
	unfullscreen_and_rewind
	#  --ff-sid and --ff-aid, that take track numbers in FFmpeg order,
	#  i.e. starting from zero within their type, do not work with
	#  certain files.
	[ "$sub_visibility" = yes ] && {
		[ -v ffmpeg_ext_subs ] \
			&& sub_file=(--sub-file "$ffmpeg_ext_subs")  # sic!
		[ -v ffmpeg_subs_tr_id ] && sid="--sid=$(( ffmpeg_subs_tr_id +1 ))"
	}
	[ -v mute ] || aid="--aid=$(( ffmpeg_audio_tr_id +1 ))"

	$mpv --x11-name mpv-nadeshiko-preview \
	     --title "Preview – $MY_DESKTOP_NAME" \
	     --input-ipc-server="$temp_sock" \
	     --start="$time1" \
	     --ab-loop-a="$time1" --ab-loop-b="$time2" \
	     --mute=$mute \
	     --sub-visibility=$sub_visibility \
	         "${sub_file[@]}" \
	         ${sid:-} \
	     ${aid:-} \
	     --osd-msg1="Preview" \
	     "$path"
	rm "$temp_sock"
	return 0
}


pick_max_size() {
	check_needed_vars
	local  max_size_default  max_size_small  max_size_tiny  kilo  \
	       fsize  fsize_val  variants  default_real_var_name  \
	       default_real_var_val
	eval $(sed -rn '/^\s*(max_size_|kilo)/p' "$CONFDIR/$nadeshiko_config")
	[ -v max_size_default ] \
	&& [ -v max_size_normal ] \
	&& [ -v max_size_small ] \
	&& [ -v max_size_tiny ] \
	&& [ -v kilo ] \
		|| err "Can’t retrieve max. file sizes from $nadeshiko_config."
	for fsize in max_size_default max_size_normal max_size_small max_size_tiny; do
		declare -n fsize_val=$fsize
		if [ "$kilo" = '1000' ]; then
			fsize_val=${fsize_val/k/ kB}
			fsize_val=${fsize_val/M/ MB}
			fsize_val=${fsize_val/G/ GB}
		elif [ "$kilo" = '1024' ]; then
			fsize_val=${fsize_val/k/ KiB}
			fsize_val=${fsize_val/M/ MiB}
			fsize_val=${fsize_val/G/ GiB}
		else
			err "kilo is set to “$kilo”, should be either 1000 or 1024."
		fi
	done

	[[ "$max_size_default" =~ ^[0-9] ]] || {
		#  Saving the name
		default_real_var_name=max_size_$max_size_default
		declare -n default_real_var_val=$default_real_var_name
		#  Dereferencing the name, now max_size_default=normal becomes =20M,
		#  for example.
		max_size_default="$default_real_var_val"
		#  Removing the variable containing the default value to avoid
		#  the confusing duplication.
		unset $default_real_var_name
	}
	for fsize in ${!max_size_*}; do
		declare -n fsize_val=$fsize
		if [ "$fsize" = max_size_default ]; then
			variants+=( "${fsize#max_size_}"
			            "$fsize_val – default"
			            on )
		elif [ "$fsize" = max_size_unlimited ]; then
			variants+=( "${fsize#max_size_}"
			            "unlimited"
			            off )
		else
			variants+=( "${fsize#max_size_}"
			            "$fsize_val"
			            off )
		fi
	done

	mpv_pid=$(get_main_playback_mpv_pid)
	show_dialogue_pick_size_$dialog
	show_dialogue_set_name_$dialog
	return 0
}


set_nadeshiko_config() {
	#  Nadeshiko-mpv only lets to choose an entry from nadeshiko_configs
	#  array, that must be present in Nadeshiko-mpv config. Whether
	#  the config really exists, is checked by Nadeshiko.
	declare -g  nadeshiko_config
	local  i  dialog_configs_list  dialog_window_height

	if  (( ${#nadeshiko_configs[*]} == 0 ));  then
		nadeshiko_config="nadeshiko.rc.sh"

	elif  (( ${#nadeshiko_configs[*]} == 1 ));  then
		nadeshiko_config="$nadeshiko_configs"

	else
		for ((i=0; i<${#nadeshiko_configs[*]}; i++)); do
			dialog_configs_list+=( "${nadeshiko_configs[i]}" )
			dialog_configs_list+=( "${nadeshiko_configs[i]}" )
			(( i == 0 )) \
				&& dialog_configs_list+=( on  ) \
				|| dialog_configs_list+=( off )
		done
		dialog_window_height=$((  116+27*${#nadeshiko_configs[*]}  ))
		show_dialogue_choose_config_file_$dialog "$dialog_window_height"
	fi

	#  Though Nadeshiko has checks for config existence, we must do it
	#  here ourselves, because we parse max_size_* variables in pick_max_size()
	#  and the config must be readable, or there will be a sed error.
	[ -e "$CONFDIR/$nadeshiko_config"  -a  -r "$CONFDIR/$nadeshiko_config" ] \
		|| err "$nadeshiko_config doesn’t exist or not readable."

	return 0
}


encode() {
	check_needed_vars
	local  audio  subs  nadeshiko_retval  command

	[ -v ffmpeg_audio_tr_id ]  \
		&& audio=audio:$ffmpeg_audio_tr_id  \
		|| audio=noaudio

	 # Never rely on “sub_visibility” property, as it is on by default:
	#  even when there’s no subtitles at all.
	if [ -v ffmpeg_ext_subs ];  then
		subs="subs=$ffmpeg_ext_subs"
	elif [ -v ffmpeg_subs_tr_id ];  then
		subs="subs:$ffmpeg_subs_tr_id"
	else
		subs='nosubs'
	fi

	if [ -e "/proc/${mpv_pid:-not exists}" ]; then
		send_command show-text 'Encoding' '2000' || exit $?
	else
		: warn-ns "Not sending anything to mpv: it was closed."
	fi


	 # “postpone” passed to nadeshiko-mpv.sh forks the process in a paused
	#    state in the background. When nadeshiko.sh (not …-mpv.sh!) is called
	#    with a single parameter “unpause”, it unfreezes the processes
	#    one by one and then quits.
	#  This allows to free the watching from humming/heating and probably,
	#    even glitchy playback, if you attempt to continue watching after
	#    firing up the encode, especially, if it’s the 2nd, the 3rd or the 15th.
	#
	nadeshiko_command=(
		"$MYDIR/nadeshiko.sh"  "$time1" "$time2" "$path"
		                       "$audio" "$subs" "$max_size"
		                       "${screenshot_directory:-$working_directory}"
		                       ${fname_pfx:+"fname_pfx=$fname_pfx"}
		                       "$nadeshiko_config"
	)
	if [ -v postpone ]; then
		for str in "${nadeshiko_command[@]}"; do
			set -x
			echo "$str" >>"$postponed_commands"
			set +x
		done
		echo >>"$postponed_commands"
		rm "$data_file"
		if [ -e "/proc/${mpv_pid:-not exists}" ]; then
			send_command  show-text \
			              "Command to encode saved for later."  \
			              '2000' \
				|| exit $?
		fi
		exit 0
	else
		errexit_off
		set -x
		"${nadeshiko_command[@]}"
		nadeshiko_retval=$?
		set +x
		errexit_on
		rm "$data_file"
		if [ -e "/proc/${mpv_pid:-not exists}" ]; then
			if [ $nadeshiko_retval -eq 0 ]; then
				send_command show-text 'Encoding done.'  '2000' || exit $?
			else
				send_command show-text 'Encoding failed.'  '3000' || exit $?
				#  Don’t display a desktop notification with an error here –
				#  nadeshiko.sh does this.
				# err 'Encoding failed.'
			fi
		else
			: warn-ns "Not sending anything to mpv: it was closed."
		fi
	fi
	return $nadeshiko_retval
}


play_encoded_file() {
	[ -v show_encoded_file ] || return 0

	local  last_log  last_file  temp_sock="$(mktemp -u)"
	check_needed_vars
	last_log=$(get_last_log nadeshiko) || {
		warn "Cannot get last log."
		return 1
	}
	info "last_log: $last_log"
	last_file=$(
		sed -rn '/Encoded successfully/ {  n
		                                   s/^.{11}//
		                                   s/.{4}$//p
		                                }' \
		        "$last_log"
	)
	info "last_file: $last_file"

	[ -e "/proc/${mpv_pid:-not exists}" ] && unfullscreen_and_rewind

	$mpv --x11-name mpv-nadeshiko-preview \
	     --title "Encoded file – $MY_DESKTOP_NAME" \
	     --input-ipc-server="$temp_sock" \
	     --loop-file=inf \
	     --mute=no \
	     --sub-visibility=yes \
	     --osd-msg1="Encoded file" \
	     "${screenshot_directory:-$working_directory}/$last_file"
	rm -f "$temp_sock"
	return 0
}



read_rcfile  "$rcfile_minver"
post_read_rcfile
REQUIRED_UTILS+=(
	$dialog  # To show a confirmation window that also sets max. file size.
	find     # To find and delete possible leftover data files.
	lsof     # To check, that there is an mpv process listening to socket.
	jq       # To parse JSON from mpv.
	pgrep
	wc
	socat
)
check_required_utils

[[ "${1:-}" =~ ^(-h|--help)$ ]] && show_help && exit 0
[[ "${1:-}" =~ ^(-v|--version)$ ]] && show_version && exit 0
#  Can be passed to set both Time1 and Time2,
#  acts only when the time to encode comes.
[ "${1:-}" ] && [ "${1:-}" = postpone ] && postpone=t
[ "$*" -a ! -v postpone ] && {
	show_help
	err 'The only parameter may be “postpone”!'
}

 # Test, that all the entries from our properties array
#  can be retrieved.
#
# retrieve_properties

 # Check connection and get us filename to serve as an ID for the playing file,
#    as for getting path we’d need working-directory. Not taking path for ID
#    to not do the job twice.
#  filename= is to be sourced well, otherwise we would have to eval.
#
get_props mpv-version filename || exit $?

data_file=$(grep -rlF "filename=$(printf '%q' "$filename")" |& head -n1)
if [ -e "$data_file" ]; then
	# Read properties.
	. "$data_file"
else
	data_file=$(mktemp --tmpdir='.'  mpvfile.XXXX)
	printf "filename=%q\n" "$filename" > "$data_file"
fi

#  If this is the first run, set time1 and quit.
#  On the second run (time2 is set) do the rest.
put_time && [ -v time2 ] && {
	#  Check the order of time values.
	arrange_times
	#  Show in a separate mpv instance, what will get in the clip.
	play_preview
	#  Choose the default or an alternative config file.
	set_nadeshiko_config
	#  Ask if the preview was what is wanted and also ask for max size.
	pick_max_size
	#  Call Nadeshiko.
	encode || exit $?
	#  Show the encoded file.
	play_encoded_file
}

exit 0