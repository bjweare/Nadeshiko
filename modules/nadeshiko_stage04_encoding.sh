#  Should be sourced.

#  stage03_encoding.sh
#  Nadeshiko module for the final stage – the encoding. This stage includes
#  the preparations too, such as combining new file name, metadata
#  and assembling the filter option string.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh


print_encoding_info() {
	local encinfo vbr_c abr_c sc_c scale_text
	#  Bright (bold) white for command line overrides.
	#  Yellow for automatic scaling.
	encoding_info="Encoding with "
	[ -v forced_vbitrate ] && vbr_c="${__bri}"
	[ -v autocorr_vbitrate ] && vbr_c="${__bri}${__y}"
	encoding_info+="${vbr_c:-}$vbitrate_pretty${__s} / "
	[ -v audio ] && {
		[ -v forced_abitrate ] && abr_c="${__bri}"
		[ -v autocorr_abitrate ] && abr_c="${__bri}${__y}"
		encoding_info+="${abr_c:-}$abitrate${__s} "
	}
	[ -v autocorr_scale ] && sc_c="${__bri}${__y}"  scale_text="${scale}p"
	[ -v forced_scale ] && sc_c="${__bri}"  scale_text="${scale}p"
	[ -v crop ] && scale_text="Cropped"
	[ -v scale_text ] || scale_text='Native'
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
	       font_list  forced_style  key
	[ -v scale ] || [ -v subs ] || [ -v crop ] && {
		[ -v subs ] && {
			#  Let’s hope that the source is an mkv and the subs are ass.
			[ -d "$TMPDIR/fonts" ] || mkdir "$TMPDIR/fonts"
			if [ -v subs_need_overlay ]; then
				#  Internal VobSub or PGS
				#  Subs may need to be centered, if their resolution doesn’t
				#  match with the video’s.
				overlay_subs_w=$( get_ffmpeg_attribute "$video"  \
				                                       "s:$subs_track_id"  \
				                                       width  )
				overlay_subs_h=$( get_ffmpeg_attribute "$video"  \
				                                       "s:$subs_track_id"  \
				                                       height  )
				[ "$overlay_subs_w" -ne "$orig_width" ] && {
					#  Need to center by X
					[ "$overlay_subs_w" -gt "$orig_width" ] \
						&& xcorr="-(overlay_w-main_w)/2" \
						|| xcorr="(main_w-overlay_w)/2"
				}
				[ "$overlay_subs_h" -ne "$orig_height" ] && {
					#  Need to center by Y
					[ "$overlay_subs_h" -gt "$orig_height" ] \
						&& ycorr="-(overlay_h-main_h)/2" \
						|| ycorr="(main_h-overlay_h)/2"
				}
				filter_list="${filter_list:+$filter_list,}"
				filter_list+="[0:v][0:s:$subs_track_id]overlay=$xcorr:$ycorr"
			else
				#  Former internal ASS/SSA, SRT/WebVTT, VobSub/PGS
				#  or initially external ASS/SSA or SRT/WebVTT.
				#
				#  This check is more of a precaution.
				[ -r "$TMPDIR/subs.ass" ] && {
					filter_list="${filter_list:+$filter_list,}"
					filter_list+="setpts=PTS+$(( ${start[total_ms]}/1000 )).${start[ms]}/TB,"
					#  “ass” filter has an option “shaping” for better font
					#  rendering, that’s not available in the “subtitles”
					#  filter. But on the other hand, “ass” doesn’t recognise
					#  option “force_style”, so we can’t use it for converted
					#  SubRip/VTT subs.
					[ -v subs_need_style_from_rc ] \
						&& filter_list+='subtitles=' \
						|| filter_list+='ass=shaping=auto:'
					filter_list+="filename=$TMPDIR/subs.ass"
					font_list="$(
						find "$TMPDIR/fonts" \( -iname "*.otf" -o -iname "*.ttf" \)
					)"
					[ "$font_list" ] \
						&& filter_list+=":fontsdir=$TMPDIR/fonts"
					[ -v subs_need_style_from_rc ] && {
						[ ${#ffmpeg_subtitle_fallback_style[*]} -gt 0 ] && {
							for key in ${!ffmpeg_subtitle_fallback_style[@]}; do
								forced_style="${forced_style:+$forced_style,}"
								forced_style+="$key="
								forced_style+="${ffmpeg_subtitle_fallback_style[$key]}"
							done
							filter_list+=":force_style='$forced_style'"
						}
					}
					#  There may be three variants:
					#  - subtitles=$TMPDIR/subs.ass:fontsdir=…,
					#  - subtitles=$TMPDIR/subs.ass:force_style=…,
					#  - or just subtitles=$TMPDIR/subs.ass,
					filter_list+=','
					filter_list+='setpts=PTS-STARTPTS'
				} || err "Subtitles are not present in $TMPDIR/subs.ass."
			fi
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
	declare -g map_string
	local map_audio
	[ -v audio ] && map_audio="-map 0:a:${audio_track_id:-0?}"
	map_string="-map 0:V ${map_audio:-}"
	return 0
}


set_file_name_and_video_title() {
	declare -g  new_file_name  video_title
	local  scale_type_tag  filename  filename_with_user_prefix  \
	       filename_without_user_prefix  timestamps  tags

	filename="${video%.*}"
	filename=${filename##*/}
	filename_with_user_prefix="${new_filename_user_prefix:-} $filename"
	filename_with_user_prefix=${filename_with_user_prefix## }
	filename_without_user_prefix="$filename"
	filename_without_user_prefix=${filename_without_user_prefix## }
	[ -v new_filename_user_prefix ] \
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

	video_title="$(get_mediainfo_attribute "$video" g 'Movie name' raw)"
	[ "$video_title" ] || video_title="$filename_without_user_prefix"
	video_title+=".$timestamps${tags:-}"
	[ -v create_windows_friendly_filenames ] \
		&& new_file_name="$(remove_windows_unfriendly_chars "$new_file_name")"
	return 0
}


encode() {
	milinc
	set_file_name_and_video_title
	print_encoding_info
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
		ffmpeg="$(which time) -f %e -o $LOGDIR/time_output -a $ffmpeg"
		declare -g time_applied=t
	}
	[ -v audio ] \
		&& audio_opts="-c:a $ffmpeg_acodec  -b:a $abitrate  -ac 2" \
		|| audio_opts="-an"
	if [ "$(type -t encode-$ffmpeg_vcodec)" = 'function' ]; then
		encode-$ffmpeg_vcodec
	else
		err "Cannot find encoding function “encode-$ffmpeg_vcodec”."
	fi
	rm -f ffmpeg2pass-0.log ffmpeg2pass-0.log.mbtree
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
	local diff_in_bytes crit_overshoot_in_bytes overshot_size_pct \
	      correction_pct less_than
	diff_in_bytes=$((  new_file_size_in_bytes - max_size_in_bytes  ))
	crit_overshoot_in_bytes=$((  max_size_in_bytes / 100 * 20  ))
	overshot_size_pct=$((  diff_in_bytes / (max_size_in_bytes / 100) ))
	[ $overshot_size_pct -eq 0 ] && overshot_size_pct=1 less_than='<'
	[ $diff_in_bytes -ge $crit_overshoot_in_bytes ] && {
		redmsg "${__y}${__bri}It’s probably impossible to encode this clip to $max_size.
		        If you think that it could be fixed, report a bug.${__s}"
		err "${__r}${__bri}Overshot size on $overshot_size_pct%.${__s}"
	}
	#  There’s a rollercoaster behaviour in VP9,
	#  that we avoid with additionally multiplying $correction_pct by two.
	correction_pct=$((overshot_size_pct*3/4))
	[ $correction_pct -eq 0 ] && correction_pct=1  # or it’ll stuck.
	warn-ns "${__bri}${__y}Overshot size on ${less_than:-}$overshot_size_pct%${__s}.
	    Increasing space, reserved for container on $correction_pct%."
	milinc
	info "Total size in bytes: $new_file_size_in_bytes."
	mildec
	((container_own_size_pct+=$correction_pct, 1))
	return 0
}


return 0