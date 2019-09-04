#  Should be sourced.

#  nadeshiko_stage03_encoding.sh
#  Nadeshiko module for the final stage – the encoding. This stage includes
#  the preparations too, such as combining new file name, metadata
#  and assembling the filter option string.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh


print_encoding_info() {
	local  encinfo  vbr_c  abr_c  sc_c  scale_text
	#  Bright (bold) white for command line overrides.
	#  Yellow for automatic scaling.
	encoding_info="Encoding with "
	[ -v forced_vbitrate ] && vbr_c="${__bri}"
	[ -v autocorrected_vbitrate ] && vbr_c="${__bri}${__y}"
	encoding_info+="${vbr_c:-}$(pretty "$vbitrate")${__s} / "
	[ -v audio ] && {
		[ -v forced_abitrate ] && abr_c="${__bri}"
		if [ -v better_abitrate_set ]; then
			abr_c="${__bri}${__g}"
		elif [ -v autocorrected_abitrate ]; then
			abr_c="${__bri}${__y}"
		fi
		encoding_info+="${abr_c:-}$(pretty "$abitrate")${__s} "
	}
	[ -v autocorrected_scale ] && sc_c="${__bri}${__y}"  scale_text="${scale}p"
	[ -v forced_scale ] && sc_c="${__bri}"  scale_text="${scale}p"
	[ -v crop ] && scale_text="at cropped resolution"
	[ -v scale_text ] || scale_text='at native resolution'
	encoding_info+="${sc_c:-}$scale_text${__s}"
	[ -v rc_default_subs -a ! -v subs ] \
		&& encoding_info+=", ${__bri}nosubs${__s}"
	[ ! -v rc_default_subs -a -v subs ] \
		&& encoding_info+=", ${__bri}subs${__s}"
	[ -v rc_default_audio -a ! -v audio ] \
		&& encoding_info+=", ${__bri}noaudio${__s}"
	[ ! -v rc_default_audio -a -v subs ] \
		&& encoding_info+=", ${__bri}audio${__s}"
	encoding_info+='.'
	info  "$encoding_info"
	return 0
}


 # Assembles -filter_complex string.
#  DO NOT put commas at the end of each filter, they can be tossed around
#  as they are.
#
assemble_vf_string() {
	declare -g vf_string
	local  filter_list  overlay_subs_w  overlay_subs_h  xcorr=0  ycorr=0  \
	       font_list  forced_style  key  tr_id  subtitle_filter

	 # In case the requested subtitles are built-in and in ASS/SSA format,
	#  they have to be extracted. This function extracts the ${src_s[track_id]}
	#  and sets  ${src_s[external_file]}  instead.  ${src_s[track_id]}  is then
	#  unset to avoid confusion in the later check.
	#
	extract_subs() {
		[ -v subtitles_are_already_extracted ] && return 0
		declare -g src_s  subtitles_are_already_extracted
		info "Extracting subtitles…"
		src_s[external_file]="$TMPDIR/subs.ass"
		# NB: -map uses 0:s:<subtitle_track_id> syntax here.
		#   It’s the number among SUBTITLE tracks, not overall!
		# “?” in 0:s:0? is to ignore the lack of subtitle track.
		#   If the default setting is to add subs, it shouldn’t lead
		#   to an error, if the source simply doesn’t have subs:
		#   specifying “nosub” for them shouldn’t be a requirement.

		FFREPORT=file=$LOGDIR/ffmpeg-subs-extraction.log:level=32  \
		$ffmpeg -y -hide_banner  -v error  -nostdin  \
		        -i "${src[path]}"  \
		        -map 0:s:${src_s[track_id]}  \
		        "${src_s[external_file]}"  \
			|| err "Cannot extract subtitle stream ${src_s[track_id]}: ffmpeg error."
		sub-msg 'Ignore ffmpeg errors, if there are any.'
		unset src_s[track_id]
		#  Saving time on re-encodes.
		subtitles_are_already_extracted=t
		return 0
	}


	extract_fonts() {
		[ -v fonts_are_already_extracted ] && return 0
		declare -g  font_list  fonts_are_already_extracted
		local font
		info "Extracting fonts…"
		milinc
		[ -d "$TMPDIR/fonts" ] || mkdir "$TMPDIR/fonts"
		if (( src_c[attachments_count] > 0 ));  then
			pushd "$TMPDIR/fonts" >/dev/null
			if ! FFREPORT=file=$LOGDIR/ffmpeg-fonts-extraction.log:level=32  \
			     $ffmpeg  -hide_banner  -v error  -nostdin  \
			              -dump_attachment:t ""  -i "${src[path]}"
			then
				#  FFmpeg may complain about that “At least one output file must
				#  be specified” but extracts all attachments. And God forbid you
				#  to try “-f null -” for this will make FFmpeg ACTUALLY START
				#  TRANSCODING the video.
				mildec  # ffmpeg’s message will not obey our indentation, so…
				sub-msg "Ignore the ffmpeg message about output, if the numbers below match."
				milinc  # back to one level deep
			fi
			info "Extracted $(ls -1A | wc -l)/${src_c[attachments_count]} attachments."
			popd >/dev/null
			font_list=$(
				find "$TMPDIR/fonts" \( -iname "*.otf" -o -iname "*.ttf" \)
			)
			for font in ${font_list[@]}; do
				if	   [[ "$font" =~ \.[Oo][Tt][Ff]$ ]]   \
					&& [ -v ffmpeg_missing[fontconfig] ]  \
					&& [ ! -v forgive[otf]  ]
				then
					redmsg 'Video uses .otf fonts, but FFmpeg was built without fontconfig
					        and will not be able to render subtitles with their native fonts.'
					redmsg 'Please install the missing fonconfig support for FFmpeg.
					        Alternatively (if you’re in a hurry and you don’t care,
					        what mess may happen in the subtitle rendering), you may re-run
					        nadeshiko with “forgive=otf” flag to bypass this error.'
					err 'FFmpeg is not able to render OTF fonts.
					     See the log for details.'
				fi
			done
		else
			info 'Video has no attachments.'
		fi
		mildec
		#  Saving time on re-encodes.
		fonts_are_already_extracted=t
		return 0
	}


	[ -v scale ] || [ -v subs ] || [ -v crop ] && {
		[ -v subs ] && {
			case "${src_s[codec]}" in

				dvd_subtitle|hdmv_pgs_subtitle)
					#  Internal VobSub or PGS (dvd and bluray) require
					#  mapping and overlay filter.
					filter_list="${filter_list:+$filter_list,}"
					#  Subtitles may need to be centered, if their resolution
					#  doesn’t match with the video’s.
					overlay_subs_w=$( get_ffmpeg_attribute "${src[path]}"  \
					                                       "s:${src_s[track_id]}"  \
					                                       width  )
					overlay_subs_h=$( get_ffmpeg_attribute "${src[path]}"  \
					                                       "s:${src_s[track_id]}"  \
					                                       height  )
					(( overlay_subs_w != src_v[width] )) && {
						#  Need to center by X
						(( overlay_subs_w > src_v[width] ))  \
							&& xcorr="-(overlay_w-main_w)/2"  \
							|| xcorr="(main_w-overlay_w)/2"
					}
					(( overlay_subs_h != src_v[height] )) && {
						#  Need to center by Y
						(( overlay_subs_h > src_v[height] ))  \
							&& ycorr="-(overlay_h-main_h)/2"  \
							|| ycorr="(main_h-overlay_h)/2"
					}
					#  Breaks syntax highlight, if put inside as is.
					local tr_id=${src_s[track_id]}
					filter_list+="[0:v][0:s:$tr_id]overlay=$xcorr:$ycorr"
					;;

				ass|ssa|subrip|srt|webvtt|vtt)
					filter_list="${filter_list:+$filter_list,}"
					filter_list+="setpts=PTS+$(( ${start[total_ms]}/1000 )).${start[ms]}/TB,"
					#  “ass” filter has an option “shaping” for better font
					#  rendering, that’s not available in the “subtitles”
					#  filter. But on the other hand, “ass” doesn’t recognise
					#  option “force_style”, so we can’t use it for converted
					#  SubRip/VTT subs.
					if [[ "${src_s[codec]}" =~ ^(subrip|srt|webvtt|vtt)$ ]]; then
						subs_need_style_from_rc=t
						subtitle_filter='subtitles'
					else
						subtitle_filter='ass'
						#  “ass” filter, being true to its name, cannot be specified
						#  subtitle track id within the video. Yes, it copies the
						#  behaviour of the “subtitles” filter, but here it does
						#  not – be so kind to disembowel the file, that may take
						#  20 gigs on the disk to take out subtitles and put it
						#  on a silver plate to ffmpeg as a separate file.
						#  REEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE—
						[ -v src_s[track_id]  ]  && extract_subs
					fi
					filter_list+="$subtitle_filter="

					#  Composing the next part of the filter string depends
					#  on whether the subtitles are in an external file or they
					#  are builtin.
					if [ -v src_s[external_file]  ]; then
						src_s[symlink_to_ext_subs]="$TMPDIR/extsubs.${src_s[external_file]##*\.}"
						ln -s "${src_s[external_file]}" "${src_s[symlink_to_ext_subs]}"
						filter_list+="filename=${src_s[symlink_to_ext_subs]}"

					elif [ -v src_s[track_id]  ]; then
						#  “ass” filter, being true to its name, requires the
						#  subtitle stream to be extracted from the file, before
						#  it can be encoded. (See the comments above.)
						[ "$subtitle_filter" = 'ass' ]  \
							&& err 'Internal subtitle track should have been extracted!'
						#  To use built-in subtitles without taking them out, the
						#  subtitles filter needs to be specified *the filename*
						#  with subtitle track index. As escaping ${src[path]} will
						#  probably lead to errors anyway, it’s simpler to create
						#  a symlink in TMPDIR and tell ffmpeg to use the file
						#  via that symlink.
						src[symlink_to_my_path]="$TMPDIR/THE_VIDEO.${src[path]##*\.}"
						ln -s "${src[path]}" "${src[symlink_to_my_path]}"
						filter_list+="${src[symlink_to_my_path]}:si=${src_s[track_id]}"
					fi

					extract_fonts
					[ "${font_list:-}" ]  \
						&& filter_list+=":fontsdir=$TMPDIR/fonts"

					[ -v subs_need_style_from_rc ] && {
						(( ${#ffmpeg_subtitle_fallback_style[*]} > 0 )) && {
							for key in ${!ffmpeg_subtitle_fallback_style[@]}; do
								forced_style="${forced_style:+$forced_style,}"
								forced_style+="$key="
								forced_style+="${ffmpeg_subtitle_fallback_style[$key]}"
							done
							filter_list+=":force_style='$forced_style'"
						}
					}

					#  For OpenType positioning and substitutions.
					[ "$subtitle_filter" = 'ass' ]  \
						&& filter_list+=':shaping=complex'

					#  There may be three variants:
					#  - subtitles=$TMPDIR/subs.ass:fontsdir=…,
					#  - subtitles=$TMPDIR/subs.ass:force_style=…,
					#  - or just subtitles=$TMPDIR/subs.ass,
					filter_list+=','
					filter_list+='setpts=PTS-STARTPTS'
					;;

			esac
		}
		[ -v crop ] && {
			filter_list="${filter_list:+$filter_list,}"
			filter_list+="$crop"
		}
		[ -v scale ] && {
			filter_list="${filter_list:+$filter_list,}"
			filter_list+="scale=-2:$scale"
		}
	}
	#  Assemble $vf_string only if $filter_list is not empty.
	[ "${filter_list:-}" ] && vf_string=(-filter_complex "$filter_list")
	return 0
}


map_streams() {
	declare -g map_string=()
	local map_audio=()
	[ -v audio ] && {
		if [ -v src_a[external_file]  ]; then
			map_audio=( -map 1:a:0 )
		else
			map_audio=( -map 0:a:${src_a[track_id]} )
		fi
	}
	map_string=( -map 0:V  "${map_audio[@]}" )
	return 0
}


set_file_name_and_video_title() {
	declare -g  new_file_name  video_title
	local  scale_type_tag  filename  filename_with_user_prefix  \
	       filename_without_user_prefix  timestamps  tags

	filename="${src[path]%.*}"
	filename=${filename##*/}
	filename_with_user_prefix="${new_filename_user_prefix:-} $filename"
	filename_with_user_prefix=${filename_with_user_prefix## }
	filename_without_user_prefix="$filename"
	filename_without_user_prefix=${filename_without_user_prefix## }
	[ -v new_filename_user_prefix ]  \
		&& declare -n filename='filename_with_user_prefix' \
		|| declare -n filename='filename_without_user_prefix'

	timestamps=" ${start[ts]}–${stop[ts]}"

	[ -v scale ] && {
		#  FS – forced scale, AS – automatic scale
		#  (including the scale= from .rc.sh).
		[ -v forced_scale ] && scale_type_tag="FS" || scale_type_tag="AS"
		tags=" [${scale}p][$scale_type_tag]"
	}

	new_file_name="$filename$timestamps${tags:-}.$container"
	new_file_name="$where_to_place_new_file/$new_file_name"

	video_title="${src_c[title]:-}"
	[ "${src_c[title]:-}" ] || video_title="$filename_without_user_prefix"
	video_title+=".$timestamps${tags:-}"
	[ -v create_windows_friendly_filenames ]  \
		&& new_file_name="$(remove_windows_unfriendly_chars "$new_file_name")"
	return 0
}


 # Launches a coprocess, that will read ffmpeg’s progress log and report
#  progress information to console.
#
launch_a_progressbar_for_ffmpeg() {
	[ -v ffmpeg_progressbar ] || return 0
	declare -g  ffmpeg_progress_log="$TMPDIR/ffmpeg_progress.log"  \
	            progressbar_pid  frame_count
	# ^ ffmpeg_progress_log must be defined before the check on whether
	#   console output should be prevented.
	[ -v do_not_report_ffmpeg_progress_to_console ] && return 0
	local progress_status  frame_no  elapsed_time
	export frame_count
	mkfifo "$ffmpeg_progress_log"
	#  Turning the cursor invisible
	tput civis

	{
		coproc {
			#  Wait for ffmpeg process to appear.
			until pgrep --session 0  -f ffmpeg  \
			      && [ -r "$ffmpeg_progress_log" ]
			do
				sleep 1
			done

			line_length=$(( TERM_COLS - ${#__mi} - 2 ))
			#  Avoid hitting the terminal border --^
			readiness_pct='100% '
			progressbar_chars='[=>-]'
			pbar_char_opbracket=${progressbar_chars:0:1}
			pbar_char_done=${progressbar_chars:1:1}
			pbar_char_processing=${progressbar_chars:2:1}
			pbar_char_to_be_done=${progressbar_chars:3:1}
			pbar_char_closbracket=${progressbar_chars:4:1}
			progressbar_length=$(( $line_length - ${#readiness_pct} - 2 ))
			#                      opening and closing brackets  -----^

			#  Leave an empty line from the corprocess pid printed by shell.
			echo

			exec {ffmpeg_progress_log_fd}<>"$ffmpeg_progress_log"


			until [ "${progress_status:-}" = end ]; do
				read -r -u "$ffmpeg_progress_log_fd"

				case "$REPLY" in

					progress=*)  #  → $progress_status

						[[ "$REPLY" =~ ^progress=(continue|end)$ ]]  \
							&& progress_status=${BASH_REMATCH[1]}  \
							|| err "FFmpeg returned an unknown value for the key “progress”: “${REPLY#progress=}”."
						;;

					frame=*)  #  → $frame_no

						#  Stripping the leading zeroes just in case
						[[ "$REPLY" =~ ^frame=([0]*)([0-9]+)$ ]]  \
							&& frame_no=${BASH_REMATCH[2]}  \
							|| err "FFmpeg returned an unknown value for the key “frame”: “${REPLY#frame=}”."
						;;

					out_time=*)  #  → $elapsed_time

						if [[ "$REPLY" =~ ^out_time=([0-9\:]+\.[0-9]{3})[0-9]*$ ]]; then
							 is_valid_timestamp "${BASH_REMATCH[1]}"  \
								 && elapsed_time="${BASH_REMATCH[1]}"  \
								 || out_time_has_an_unknown_value=t
						else
							out_time_has_an_unknown_value=t
						fi
						[ -v out_time_has_an_unknown_value ]  \
							&& err "FFmpeg returned an unknown value for the key “out_time”: “${REPLY#out_time=}”."
						;;

				esac

				[ "${progress_status:-}" = end ] && frame_no=$frame_count
				[ -v frame_no ] || continue

				#  Exporting it for the subshell with printf
				export frame_no

				#  Caret return.
				echo -en "\r"

				#  Message indentation.
				echo -n "$__mi"

				#  Readiness.
				readiness_pct="$(printf '%3d' $(( frame_no * 100 / frame_count )))"
				echo -n "${readiness_pct}% ["

				 # Assembling a line of blocks, that represent what is done.
				#    Literally, how much characters the done blocks comprise
				#    in the progressbar.
				#  Also avoiding the bug, when the encoding is finished,
				#    but the bar ends with ==>-]
				#
				if (( readiness_pct == 100 )); then
					blocks_done_no=$progressbar_length

				elif (( readiness_pct < 100 )); then
					blocks_done_no=$(( frame_no * progressbar_length / frame_count ))

				elif (( readiness_pct > 100 )); then
					#  A bug was reported, when readiness has exceeded the
					#  $frame_count in the clip. For this bug the bar should
					#  have the “progress going” block (usually ‘>’), so the
					#  bar should end like '…======>?  '
					blocks_done_no=$(( progressbar_length -1 ))

				fi

				 # The last block done (the last ‘=’) will be replaced with
				#  the progress block (i.e. ‘>’), so it is necessary to have
				#  at least one block here. (Otherwise a line like ‘------’)
				#  may confuse the user into thinking, that ffmpeg cannot
				#  start for some reason.
				#
				(( blocks_done_no == 0 )) && blocks_done_no=1
				blocks_done_chars=''
				for (( i=0; i<blocks_done_no-1; i++ )); do
					blocks_done_chars+='='
				done
				(( readiness_pct == 100 ))  \
					&& blocks_done_chars+='='  \
					|| blocks_done_chars+='>'
				echo -n "$blocks_done_chars"

				 # Now assembling the string of blocks that are “to be done”.
				#
				blocks_to_be_done_no=$(( progressbar_length - blocks_done_no ))
				blocks_to_be_done_chars=''
				for (( i=0; i<blocks_to_be_done_no; i++ )); do
					blocks_to_be_done_chars+='-'
				done
				echo -n "$blocks_to_be_done_chars"

				 # Avoiding the bug with the percentage exceeding 100.
				#  Why it exceeds 100% is not yet known – the reporter didn’t
				#  provide sufficient information about the case.
				#
				(( readiness_pct <= 100 ))  \
					&& echo -n ']'  \
					|| echo -n '?'

			done


			 # Jumping off from the line with progress bar and making
			#  an empty line after the bar, symmetric to the empty line above.
			#  (The line above is necessary to avoid clutter caused by printed
			#  (co)process id.)
			#
			echo -en '\n\n'
			exit 0
		} >&${STDOUT_ORIG_FD} 2>&${STDERR_ORIG_FD}
	} || true   #  errors in progressbar are not critical.
	progressbar_pid=$!
	return 0
}


stop_the_progressbar_for_ffmpeg() {
	[ -v ffmpeg_progressbar ] || return 0
	[ -v do_not_report_ffmpeg_progress_to_console ] && return 0
	local i
	#  Wait for a maximum of five seconds for progressbar coprocess to finish.
	for ((i=0; i<5; i++)); do
		[ -e /proc/$progressbar_pid ] && sleep 1 || break
	done
	#
	#  Progressbar process might quit by itself, but if it did not,
	#  it has to be killed. The “echo” is for the output to jump off
	#  the line with the progressbar, because if kill has succeeded,
	#  the function can’t do it, obviously.
	#
	if [ -e /proc/$progressbar_pid ]; then
		(( $(get_bahelite_verbosity console) >= 5 ))  \
			&& info 'After 5 seconds, progressbar subprocess is still running.'
		if kill -TERM $progressbar_pid 2>/dev/null; then
			echo -en '\n\n'
			(( $(get_bahelite_verbosity console) >= 5 ))  \
				&& info 'Killed progressbar process.'
		else
			(( $(get_bahelite_verbosity console) >= 5 ))  \
				&& info "Progress bar finished by itself after $i seconds in the last moment."
		fi
	else
		(( $(get_bahelite_verbosity console) >= 5 ))  \
			&& info "Progress bar finished by itself after $i seconds."
	fi
	rm -f "$ffmpeg_progress_log"
	#  Turning the cursor visible again
	tput cnorm
	return 0
}


encode() {
	local audio_opts  acodec_options
	local ffmpeg_input_files=( -i "${src[path]}" )
	#  External audio goes as a separate input file, subtitles go within the
	#  string passed as a parameter to -filter_complex
	if [ -v src_a[external_file]  ]; then
		ffmpeg_input_files+=( -i "${src_a[external_file]}" )
	fi
	print_encoding_info
	milinc
	set_file_name_and_video_title
	[ -v dryrun ] && exit 0
	assemble_vf_string
	map_streams
	[ -v ffmpeg_colorspace  -a  ! -v ffmpeg_colorspace_prepared ] && {
		ffmpeg_color_primaries=(-color_primaries "$ffmpeg_color_primaries")
		ffmpeg_color_trc=(-color_trc "$ffmpeg_color_trc")
		ffmpeg_colorspace=(-colorspace "$ffmpeg_colorspace")
		ffmpeg_colorspace_prepared=t
	}
	[ -v time_stat -a ! -v time_applied ] && {
		#  Could be put in set_vars, but time is better to be applied after
		#  $vf_string is assembled, or we get conditional third time.
		ffmpeg="command time -f %e -o $LOGDIR/time_output -a $ffmpeg"
		declare -g time_applied=t
	}
	if [ -v audio ]; then
		if [ -v forced_audio ]; then
			[ -v "${ffmpeg_acodec}_forced_cbr_warning" ] &&  {
				#  Forcing audio bitrate is generally not recommended for
				#  several reasons:
				#  - some codecs may not support CBR at all;
				#  - some support it poorly (quality is not guaranteed);
				#  - some have only a limited set of bitrates that can
				#    be used.
				#  - FFmpeg will try to use or convert -b:a to codec options,
				#    but it doesn’t guarantee, that you’ll get what you
				#    expect.
				declare -n forced_cbr_warning=${ffmpeg_acodec}_forced_cbr_warning
				warn-ns "$forced_cbr_warning"
			}
			audio_opts=( -c:a $ffmpeg_acodec -ac 2 -b:a $abitrate )
		else
			declare -n acodec_options=${ffmpeg_acodec}_profiles[$acodec_profile]
			audio_opts=( -c:a $ffmpeg_acodec -ac 2 $acodec_options )
		fi
	else
		audio_opts=( -an )
	fi
	if [ "$(type -t encode-$ffmpeg_vcodec)" = 'function' ]; then
		encode-$ffmpeg_vcodec
	else
		err "Cannot find encoding function “encode-$ffmpeg_vcodec”."
	fi
	mildec
	return 0
}


print_stats() {
	local stats  pass1_s    pass2_s    pass1_and_pass2_s \
	             pass1_hms  pass2_hms  pass1_and_pass2_hms
	read -d '' pass1_s pass2_s < <( cat "$LOGDIR/time_output"; echo -e '\0' )
	pass1_s=${pass1_s%.*}  pass2_s=${pass2_s%.*}
	[[ "$pass1_s" =~ ^[0-9]+$ && "$pass2_s" =~ ^[0-9]+$ ]] || {
		warn "Couldn’t retrieve time spent on the 1st or 2nd pass."
		return 0
	}
	pass1_and_pass2_s=$((  pass1_s + pass2_s  ))
	new_time_array  pass1_time  $pass1_s
	new_time_array  pass2_time  $pass2_s
	new_time_array  pass1_and_pass2_time  $pass1_and_pass2_s
	speed_ratio=$(echo "scale=2; $pass1_and_pass2_s/${duration[total_s]}" | bc)
	speed_ratio="${__bri}${__y}$speed_ratio${__s}"
	info "Stats:
	      Pass 1 – ${pass1_time[ts_no_ms]}.
	      Pass 2 – ${pass2_time[ts_no_ms]}.
	       Total – ${pass1_and_pass2_time[ts_no_ms]}.
	      Encoding took $speed_ratio× time of the slice duration."
	return 0
}


 # Analyses the ratio, on which the size was overshot.
#  Depending on that ratio, does one of two things:
#  - if ratio is less than or equal to 1/5, set container padding
#    to 3/4 of the overshot size. Nadeshiko will encode again.
#  - if ratio is more than 1/5, consider the file unencodable and quit.
#
on_size_overshoot() {
	declare -g  muxing_overhead_antiovershoot  \
	            new_file_size_B  \
	            max_size_B  \
	            min_esp_unit  \
	            esp_unit

	local filesize_overshoot  previous_muxing_overhead_antiovershoot  \
	      muxing_overhead_antiovershoot_in_esp

	filesize_overshoot=$((  ( new_file_size_B - max_size_B ) * 8  ))

	filesize_overshoot_in_esp=$((  filesize_overshoot / esp_unit  ))

	#  Assign to antiovershoot appendage 3/4 of the overhead space in bits.
	#  (3/5, because as the increase in the overhead will shrink the data,
	#   and they will generate less overhead, than was observed in the first
	#   time. The jumps in taken space are sometimes drastic in VP9, so 3/5.)


	#  Guarantee, that the antiovershoot appendage increases on at least 1 ESP
	#  (Min esp unit should ideally be replaced here with a desired bitrate
	#   of the profile below, and min esp unit should be used, only when
	#   there is no bitres profile below the current one.)
	to_bits '*min_esp_unit'
	: ${filesize_antiovershoot:=0}
	if  (( filesize_overshoot * 3/4  >=  min_esp_unit )); then
		let "filesize_antiovershoot +=  filesize_overshoot * 3/4,  1"
	else
		let "filesize_antiovershoot +=  min_esp_unit,  1"
	fi

	#  Calculations below this point are only to print info to the user.
	overshoot_size_B=$(( new_file_size_B - max_size_B ))
	if  ((      max_size_B > 5*1024*1024
		    &&  overshoot_size_B > (max_size_B * 1/5)  ))
	then
		#  For the file sizes over 5 MiB overshooting on more than 1/5
		#  may lead to a long, continuous and most probably fruitless
		#  re-encode, that may be infuriating, when all the gigawatts eaten
		#  would happen to be wasted to no avail.
		#
		redmsg "${__bri}${__y}It’s probably impossible to encode this clip to $max_size.
		        If you think that it could be fixed, report a bug.${__s}"
		err "${__bri}${__r}Overshot size on more than 20%.${__s}"
	fi

	warn-ns "${__bri}${__y}Overshot size on $(pretty $filesize_overshoot) (≈$filesize_overshoot_in_esp ESP)${__s}.
	    Increasing space, reserved for container on $(pretty $filesize_antiovershoot) (coef = 0.75)."

	milinc
	info "Total size in bytes: $new_file_size_B."
	mildec

	: ${overshot_times:=0}
	let "++overshot_times, 1"
	return 0
}


return 0