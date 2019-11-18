#  Should be sourced.

#  05_display_assessed_parameters.sh
#  Nadeshiko module with a function to display
#    - the information gathered about the source file;
#    - a mould of options set by defconf, user’s RC file and from the command
#      line, along with with which of the options were altered at runtime
#      (e.g. audio disabled because the source file had none and no external
#      audio track was specified).
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh



 # Prints the initial settings to the user.
#  This output combines the data from the RC file, the command line,
#  and the source video. No decision how to fit the clip in the constraints
#  has been made yet.
#
display_assessed_parameters() {
	local  sub_hl
	local  audio_hl
	local  crop_string
	local  sub_hl
	local  audio_hl
	local  src_var
	local  src_varval
	local  key

	# The colours for all the output should be:
	# - default colour for default/computed/retrieved data;
	# - bright white colour indicates command line overrides;
	# - bright yellow colour shows the changes, that the code applied itself.
	#   This includes lowering bitrates for 4:3 videos, going downscale,
	#   when the size doesn’t allow for encode at the native resolution etc.
	info 'Requested settings:' && milinc
	info "$ffmpeg_vcodec + $ffmpeg_acodec → $container"
	# Highlight only overrides of the defaults.
	# The defaults are defined in $rc_file.
	[ -v rc_default_subs -a -v subs ]  \
		&& sub_hl="${__g}"  \
		|| sub_hl="${__bri}"
	[ -v subs ] \
		&& info "Subtitles are ${sub_hl}ON${__s}."  \
		|| info "Subtitles are ${sub_hl}OFF${__s}."
	[ -v rc_default_audio -a -v audio ]  \
		&& audio_hl="${__g}"  \
		|| audio_hl="${__bri}"
	[ -v audio ]  \
		&& info "Audio is ${audio_hl}ON${__s}."  \
		|| info "Audio is ${audio_hl}OFF${__s}."
	[ -v scale ] && {
		[ "${rc_default_scale:-}" != "${scale:-}" ] && scale_hl=${__bri}
		info "Scaling to ${scale_hl:-}${scale}p${__s}."
	}
	[ -v crop ] && {
		crop_string="${__bri}$crop_w×$crop_h${__s}, X:$crop_x, Y:$crop_y"
		info "Cropping to: $crop_string."
	}
	[ "$max_size" = "$max_size_default" ]  \
		&& info "Size to fit into: $max_size (kilo=$kilo)."  \
		|| info "Size to fit into: ${__bri}$max_size${__s} (kilo=$kilo)."
	info "Slice duration: ${duration[ts_short_no_ms]} (exactly ${duration[total_s_ms]})."

	mildec
	info 'Source video properties:'
	milinc

	for src_var in  src_c  src_v  src_a  src_s; do
		[ "$src_var" = src_a ] && [ ! -v audio ] && continue
		[ "$src_var" = src_s ] && [ ! -v subs  ] && continue
		local -n src_varval=$src_var
		case $src_var in
			src_c)
				msg 'Container'
				;;
			src_v)
				msg 'Video'
				;;
			src_a)
				msg 'Audio'
				;;
			src_s)
				msg 'Subtitles'
				;;
		esac
		milinc
		for key in ${!src_varval[*]}; do
			msg "$key: ${src_varval[$key]}"
		done
		mildec
	done
	mildec

	info 'Clip properties:'
	milinc
	if [ -v scene_complexity_assumed ]; then
		warn "Scene complexity: assumed to be $scene_complexity."
	else
		if [ -v forced_scene_complexity ]; then
			msg "Scene complexity: ${__bri}$scene_complexity${__s}."
		else
			msg "Seconds per scene: ${sps_ratio:-scene complexity is forced}."
			msg "Scene complexity: $scene_complexity."
		fi
	fi
	msg "Frame count: $frame_count"
	mildec

	local -n vcodec_pix_fmt=${ffmpeg_vcodec//-/_}_pix_fmt
	[ "$vcodec_pix_fmt" != "yuv420p" ]  \
		&& info "Encoding to pixel format “${__bri}$vcodec_pix_fmt${__s}”."
	[ -v ffmpeg_colorspace ]  \
		&& info "Converting to colourspace “${__bri}$ffmpeg_colorspace${__s}”."
	[    -v needs_bitrate_correction_by_origres  \
	  -o -v needs_bitrate_correction_by_cropres ] && {
	  	infon 'Bitrate corrections to be applied: '
		[ -v needs_bitrate_correction_by_origres ]  \
			&& echo -en "by ${__y}${__bri}orig_res${__s} "
		[ -v needs_bitrate_correction_by_cropres ]  \
			&& echo -en "by ${__y}${__bri}crop_res${__s} "
		echo
	}

	#  Separating the prinout of the initial properties
	#  from the calculations that will follow.
	echo
	return 0
}


return 0