#! /usr/bin/env bash

# nadeshiko.sh
#   A Linux tool to cut small videos with ffmpeg.
#   deterenkelt © 2018

# This program is free software; you can redistribute it and/or modify it
#   under the terms of the GNU General Public License as published
#   by the Free Software Foundation; either version 3 of the License,
#   or (at your option) any later version.
# This program is distributed in the hope that it will be useful,
#   but without any warranty; without even the implied warranty
#   of merchantability or fitness for a particular purpose.
#   See the GNU General Public License for more details.

set -feEu
shopt -s extglob
declare -r BHLLS_LOGGING_ON=t
# Logging, error handling, messages to console and desktop.
. "$(dirname "$0")/bhlls.sh"
# Parsing ffprobe and mediainfo output into usable format.
. "$MYDIR/gather_file_info.sh"

declare -r rc_file="$MYDIR/nadeshiko.rc.sh"
declare -r example_rc_file="$MYDIR/example.nadeshiko.rc.sh"
declare -r version='20180311'
declare -r MY_MSG_TITLE='Nadeshiko'
where_to_place_new_file=$PWD

 # Reading the RC file.
#
if [ -r "$rc_file" ]; then
	. "$rc_file"
else
	if [ -r "$example_rc_file" ]; then
		cp "$example_rc_file" "$rc_file" || err "Couldn’t create RC file!"
		. "$rc_file"
	else
		err "No RC file or example RC file was found!"
	fi
fi
# Let the defaults for these parameters be determined by the user.
[ -v subs ] && rc_default_subs=t
[ -v audio ] && rc_default_audio=t
[ -v scale ] && {
	[[ "$scale" =~ ^(360|480|576|720|1080)p$ ]] \
		|| err "RC: scale should one of 1080p, 720p, 576p, 480p, 360p."
	# NB Scale from RC doesn’t set force_scale!
	scale=${scale%p} && rc_default_scale=$scale
}

show_help() {
	cat <<-EOF
	Usage
	./nadeshiko.sh  <start_time> <stop_time> [OPTIONS] <source video>

	Required options
	         start_time – Time from the beginning of <source video>.
	          stop_time   Any formats are possible:
	                      01:23:45.670   = 1 h 23 min 45 s 670 ms
	                         23:45.1     = 23 min 45 s 100 ms
	                             5       = 5 s
	                      Padding zeroes aren’t required.
	       source video – Path to the source videofile.

	Other options
	            (no)sub – enable/disable hardsubs. Default is do hardsub.
	          (no)audio – use/throw away audio track. Default is to add.
	         si, k=1000 – Only for maximum file size – when converting
	                      [kMG] suffixes, use 1000 instead of 1024.
	          <format>p – force encoding to the specified resolution,
	                      <format> is one of: 1080, 720, 576, 480, 360.
	       small | tiny – override the default maximum file size (20M).
	        | unlimited   Values must be set in nadeshiko.rc.sh beforehand.
	                      Default presets are: small=10M, tiny=2M.
	    vb<number>[kMG] – force video bitrate to specified <number>.
	                      A suffix may be applied: vb300000, vb1200k, vb2M.
	      ab<number>[k] – force audio bitrate the same way.
	                      Example: ab128000, ab192k, ab88k.
	       crop=W:H:X:Y – crop video. Cannot be used with scale.
	           <folder> – place encoded file in the <folder>.

	The order of options is unimportant. Throw them in,
	Nadeshiko will do her best.

	https://github.com/deterenkelt/Nadeshiko
	EOF
	exit 0
}

show_version() {
	cat <<-EOF
	nadeshiko.sh $version
	© deterenkelt 2018.
	Licence GPLv3+: GNU GPL ver. 3 or later <http://gnu.org/licenses/gpl.html>
	This is free software: you are free to change and redistribute it.
	There is no warranty, to the extent permitted by law.
	EOF
	exit 0
}

 # Check, that all needed utils are in place and ffmpeg supports
#  user’s encoders.
#
check_util_support() {
	local codec_list missing_encoders arg
	for arg in "$@"; do
		case "$arg" in
			video)
				required_utils+=(
					# For encoding. 3.4.2+ recommended.
					ffmpeg
					# For retrieving data from the source video
					# and verifying resulting video.
					ffprobe
					# For the parts not retrievable with ffprobe
					# and as a fallback option for when ffprobe fails.
					mediainfo
				)
				;;
			subs)
				required_utils+=(
					# To get the list of attachments in the source video.
					mkvmerge
					# To extract subtitles and fonts from the source video.
					# (subtitles are needed for hardsubbing, and the hardsub
					# will be poor without built-in fonts).
					mkvextract
				)
				;;
			time_stat)
				required_utils+=(
					# To output how many seconds the encoding took.
					# Only pass1 and pass2, no fonts/subtitles extraction.
					time
				)
				;;
		esac
	done
	check_required_utils || err "Missing dependencies."
	codec_list=$($ffmpeg -hide_banner -codecs)
	for arg in "$@"; do
		case "$arg" in
			video)
				grep -qE "\s.EV... .*encoders:.*$ffmpeg_vcodec" \
					<<<"$codec_list" || {
					warn "FFmpeg doesn’t support $ffmpeg_vcodec encoder."
					missing_encoders=t
				}
				;;
			audio)
				grep -qE "\s.EA... .*encoders:.*$ffmpeg_acodec" \
					<<<"$codec_list" || {
					warn "FFmpeg doesn’t support $ffmpeg_acodec encoder."
					missing_encoders=t
				}
				;;
			subs)
				grep -qE "\s.ES... ass" <<<"$codec_list" || {
					warn "FFmpeg doesn’t support encoding ASS subtitles."
					missing_encoders=t
				}
				;;
		esac
	done
	[ -v missing_encoders ] \
		&& err "FFmpeg doesn’t support requested encoder(s)."
	return 0
}

 # Assigns start time, stop time, source video file
#  and other stuff from command line parameters.
#  $@ – see show_help()
#
parse_args() {
	args=("$@")
	for arg in "${args[@]}"; do
		if [[ "$arg" = @(-h|--help) ]]; then
			show_help
		elif [[ "$arg" = @(-v|--version) ]]; then
			show_version
		#                    /hours\      /minutes\      /seconds\     /mseconds\
		elif [[ "$arg" =~ ^(([0-9]{1,2}:|)([0-9]{1,2}:)|)([0-9]{1,2})(\.[0-9]{1,3}|)$ ]]; then
		#                                 ^           ^  ^          ^
		# These are only to extract faster. Remove them to see the regex clearer.
			if [ -v time1 ]; then
				time2_h="${BASH_REMATCH[2]%:}"
				time2_m="${BASH_REMATCH[3]%:}"
				time2_s="${BASH_REMATCH[4]}"
				time2_ms="${BASH_REMATCH[5]#\.}"
				# Guarantee, that HH MM SS are two digit numbers here
				for var in time2_h time2_m time2_s; do
					declare -n time=$var
					until [[ "$time" =~ ^..$ ]]; do time="0$time"; done
				done
				# Guarantee, that milliseconds have proper zeroes and are
				#   a three digit number.
				#   (.1 should later count as 100 ms, not 1 ms)
				until [[ "$time2_ms" =~ ^...$ ]]; do time2_ms+='0'; done
				# Here it must be guaranteed, that:
				#   - timeX_Y variables are not empty – or we’ll be summing
				#     emptiness $((  +  +  +  )).
				#   - timeX_Y variables that are not zeroes, do not have
				#     leading zeroes. Otherwise they’ll be treated as octal
				#     numbers in bash.
				# The issue with 0-prepended numbers treated as octal numbers
				#   can be mitigated with prepending the variables with 10#,
				#   as in 10##{time2_h#0}. The need to strip leading zeroes
				#   falls off along with it. We might not force fixed length
				#   digits, however, having them makes the code bulletproof
				#   against other problems like “what if the user didn’t
				#   type in hours? time2_h will be empty then!”.
				#
				time2_total_ms=$((   ${time2_h#0}*3600000
				                   + ${time2_m#0}*60000
				                   + ${time2_s#0}*1000
				                   + ${time2_ms##@(0|00)}  ))
				time2="$time2_h:$time2_m:$time2_s.$time2_ms"
			else
				time1_h="${BASH_REMATCH[2]%:}"
				time1_m="${BASH_REMATCH[3]%:}"
				time1_s="${BASH_REMATCH[4]}"
				time1_ms="${BASH_REMATCH[5]#\.}"
				for var in time1_h time1_m time1_s; do
					declare -n time=$var
					until [[ "$time" =~ ^..$ ]]; do time="0$time"; done
				done
				until [[ "$time1_ms" =~ ^...$ ]]; do time1_ms+='0'; done
				time1_total_ms=$((   ${time1_h#0}*3600000
				                   + ${time1_m#0}*60000
				                   + ${time1_s#0}*1000
				                   + ${time1_ms##@(0|00)}  ))
				time1="$time1_h:$time1_m:$time1_s.$time1_ms"
			fi
		elif [[ "$arg" =~ ^(no|)subs?$ ]]; then
			case "${BASH_REMATCH[1]}" in
				no) unset subs ;;
				'')	subs=t ;;
			esac
		elif [[ "$arg" =~ ^(no|)audio$ ]]; then
			case "${BASH_REMATCH[1]}" in
				no) unset audio ;;
				'')	audio=t ;;
			esac
		elif [[ "$arg" =~ ^(si|kilo=1000|k=1000)$ ]]; then
			kilo=1000
		elif [[ "$arg" =~ ^(360|480|576|720|1080)p$ ]]; then
			scale="${BASH_REMATCH[1]}"
		elif [[ "$arg" =~ ^(tiny|small|unlimited)$ ]]; then
			declare -gn max_size="max_size_$arg"
		elif [[ "$arg" =~ ^(vb|ab)([0-9]+[kMG])$ ]]; then
			[ "${BASH_REMATCH[1]}" = vb ] && vbitrate="${BASH_REMATCH[2]}"
			[ "${BASH_REMATCH[1]}" = ab ] && abitrate="${BASH_REMATCH[2]}"
		elif [[ "$arg" =~ ^crop=([0-9]+):([0-9]+):([0-9]+):([0-9]+)$ ]]; then
			crop_w=${BASH_REMATCH[1]}
			crop_h=${BASH_REMATCH[2]}
			crop_x=${BASH_REMATCH[3]}
			crop_y=${BASH_REMATCH[4]}
			crop="crop=trunc($crop_w/2)*2:"
			crop+="trunc($crop_h/2)*2:"
			crop+="trunc($crop_x/2)*2:"
			crop+="trunc($crop_y/2)*2"
		elif [ -f "$arg" ]; then
			video="$arg"
		elif [ -d "$arg" ]; then
			if [ -w "$arg" ]; then
				where_to_place_new_file="$arg"
			else
				err "Cannot write to directory “$arg”."
			fi
		else
			err "“$arg”: parameter unrecognised."
		fi
	done
	[ -v video ] && [ -v time1 ] && [ -v time2 ] \
		&& [ $time1_total_ms -ne $time2_total_ms ] \
		|| err "Set video file, start time and stop time!"
	return 0
}

set_vars() {
	can_be_used_together=(
		'mp4 libx264 libfdk_aac aac'
		# 'mp4 libx264 libopus'  # libopus in mp4 is still experimental
		# 'mkv libx264 libopus libfdk_aac aac' # browsers do not recognise mkv
		'webm libvpx-vp9 libopus libvorbis '
	)
	[ "$container" = auto ] && case "$ffmpeg_vcodec" in
		libx264) container=mp4;;
		libvpx-vp9) container=webm;;
	esac
	for combination in "${can_be_used_together[@]}"; do
		[[ "$combination" =~ ^.*$container.*$ ]] \
			&& [[ "$combination" =~ ^.*$ffmpeg_vcodec.*$ ]] \
			&& [[ "$combination" =~ ^.*$ffmpeg_acodec.*$ ]] \
			&& combination_passes=t
	done
	[ -v combination_passes ] || {
		warn "“$container”, “$ffmpeg_vcodec” and “$ffmpeg_acodec” cannot be used together.
		      Possible combinations include:
		      libx264 + libfdk_aac/aac in mp4
		      libvpx-vp9 + libvorbis/libopus in webm"
		err 'Incompatible container or A/V codecs.'
	}
	[ -v max_size ] || declare -g max_size=$max_size_default
	[ -v abitrate  -a  ! -v audio ] \
		&& err "“noaudio” cannot be used with forced audio bitrate."
	[ -v crop  -a  -v scale ] \
		&& err "crop and scale cannot be used at the same time."
	if [ $time2_total_ms -gt $time1_total_ms ]; then
		declare -gn start='time1' \
		            start_h='time1_h' \
		            start_m='time1_m' \
		            start_s='time1_s' \
		            start_ms='time1_ms' \
		            start_total_ms='time1_total_ms' \
		            stop='time2' \
		            stop_h='time2_h' \
		            stop_m='time2_m' \
		            stop_s='time2_s' \
		            stop_ms='time2_ms' \
		            stop_total_ms='time2_total_ms'
	else
		declare -gn start='time2' \
		            start_h='time2_h' \
		            start_m='time2_m' \
		            start_s='time2_s' \
		            start_ms='time2_ms' \
		            start_total_ms='time2_total_ms' \
		            stop='time1' \
		            stop_h='time1_h' \
		            stop_m='time1_m' \
		            stop_s='time1_s' \
		            stop_ms='time1_ms' \
		            stop_total_ms='time1_total_ms'
	fi
	duration_total_ms=$((stop_total_ms - start_total_ms))
	duration_total_s=$((duration_total_ms/1000))
	duration_hms=$(get_duration_hms $duration_total_s)
	# Getting the original video and audio bitrate.
	orig_video_bitrate=$(get_mediainfo_attribute "$video" v 'Nominal bit rate')
	[ "$orig_video_bitrate" ] \
		|| orig_video_bitrate=$(get_mediainfo_attribute "$video" v 'Bit rate')
	if [ "$orig_video_bitrate" != "${orig_video_bitrate%kb/s}" ]; then
		orig_video_bitrate=${orig_video_bitrate%kb/s}
		orig_video_bitrate=${orig_video_bitrate%.*}
	elif [ "$orig_video_bitrate" != "${orig_video_bitrate%Mb/s}" ]; then
		orig_video_bitrate=${orig_video_bitrate%Mb/s}
		orig_video_bitrate=${orig_video_bitrate%.*}
		orig_video_bitrate=$((orig_video_bitrate*1000))
	fi
	if [[ "$orig_video_bitrate" =~ ^[0-9]+$ ]]; then
		orig_video_bitrate_bits=$((orig_video_bitrate*1000))
	else
		# Unlike with the resolution, original bitrate
		# is of less importance, as the source will most likely
		# have bigger bit rate, and no bad things will happen
		# from wasting (limited) space on quality.
		warn 'Couldn’t retrieve bitrate of the original video.'
		no_orig_video_bitrate=t
	fi

	# Original resolution is a prerequisite for the intelligent mode.
	#   Dumb mode with some hardcoded default bitrates bears
	#   little usefullness, so it was decided to flex it out.
	#   Intelligent and forced modes (that overrides things in the former)
	#   are the two modes now.
	# Getting native video resolution is of utmost importance
	#   to not do accidental upscale. It is also needed for knowing,
	#   with which resolution to start scaling down, if needed.
	orig_width=$(get_ffmpeg_attribute "$video" v width)
	orig_height=$(get_ffmpeg_attribute "$video" v height)
	if [[ "$orig_width" =~ ^[0-9]+$ && "$orig_height" =~ ^[0-9]+$ ]]; then
		have_orig_res=t
	else
		#  Files in which native resolution could not be obtained,
		#  haven’t been met in the wild, but let’s try a different
		#  way of obtaining it.
		orig_width=$(get_mediainfo_attribute "$video" v Width)
		orig_width="${orig_width%pixels}"
		orig_height=$(get_mediainfo_attribute "$video" v Height)
		orig_height="${orig_height%pixels}"
		[[ "$orig_width" =~ ^[0-9]+$ && "$orig_height" =~ ^[0-9]+$ ]] \
			&& have_orig_res=t
	fi
	#  If we couldn’t obtain original resolution or command line
	#  parameter haven’t forced a specific scale, quit.
	[ -v have_orig_res -o -v scale ] || {
		# Without have_orig_res no resolution profile can be applied,
		# hence no bitrate settings too. Unless there would be scale,
		# that tells which profile to use.
		vbitrate=$fallback_vbitrate
		abitrate=$fallback_abitrate
		warn "Can’t get native video resolution, hence no profile to apply."
		warn-ns "Forcing fallback bitrates."
	}
	#  Since in our tables desireable/minimal bitrates are given
	#  for 16:9 aspect ratio, 4:3 video would require on 25% less
	#  bitrate, as there’s 25% less pixels.
	orig_ar=$(get_mediainfo_attribute "$video" v 'Display aspect ratio')
	[ "$orig_ar" = '4:3' ] && ar_bitrate_correction='*3/4'
	[ -v crop ] && {
		orig_total_px=$(( orig_width * orig_height
		                  ${ar_bitrate_correction:-}  ))
			crop_total_px=$((crop_w * crop_h))
			crop_to_orig_total_px_ratio=$((    crop_total_px
			                                 * 100
			                                 / orig_total_px  ))
			# compensation for the lost fractional part
			((crop_to_orig_total_px_ratio++, 1))
			crop_bitrate_correction="*$crop_to_orig_total_px_ratio/100"
			# juuust in caaase…
			[ $crop_to_orig_total_px_ratio -eq 100 ] && unset crop
	}
	[ -v scale ] && [ $scale -eq $orig_height ] && {
		warn "Disabling scale to ${scale}p – it is native resolution."
		unset scale
	}
	[ -v scale ] && [ $scale -gt $orig_height ] && {
		warn "Disabling scale to ${scale}p – would be an upscale."
		unset scale
	}
	orig_writing_lib=$(get_mediainfo_attribute "$video" v 'Writing library')
	[[ "$orig_writing_lib" =~ ^.*${ffmpeg_vcodec//lib/}.*$ ]] \
		&& orig_codec_same_as_enc=t
	lower_res_list=( 1080 720 576 480 360 )
	closest_lowres_index=0
	for ((i=0; i<${#lower_res_list}; i++ )); do
		# If a table resolution is greater than or equal
		#   to the source video height, such resolution isn’t
		#   actually lower, and we don’t need upscales.
		# If we intend to scale down the source and the desired
		#   resolution if higher than the table resolution,
		#   again, it should be skipped.
		(
			[ -v orig_height ] && [ ${lower_res_list[i]} -ge $orig_height ]
		)||(
			[ -v scale ] && [ ${lower_res_list[i]} -gt $scale ]
		) \
		&& ((closest_lowres_index++, 1))
	done

	 # If any of these variables are set by this time,
	#  they are set forcefully.
	[ -v vbitrate ] && forced_vbitrate=t
	[ -v abitrate ] && forced_abitrate=t
	# scale is special, it can be set in RC file.
	[ -v scale  -a  ! -v rc_default_scale ] && forced_scale=t
	return 0
}

display_settings(){
	local sub_hl audio_hl crop_string sub_hl audio_hl
	# The colours for all the output should be:
	# - default colour for default/computed/retrieved data;
	# - bright white colour indicates command line overrides;
	# - bright yellow colour shows the changes, that the code applied itself.
	#   This includes lowering bitrates for 4:3 videos, going downscale,
	#   when the size doesn’t allow for encode at the native resolution etc.
	info "$ffmpeg_vcodec + $ffmpeg_acodec → $container"
	# Highlight only overrides of the defaults.
	# The defaults are defined in $rc_file.
	[ -v rc_default_subs -a -v subs ] \
		&& sub_hl="${__g}" \
		|| sub_hl="${__b}"
	[ -v subs ] \
		&& info "Subtitles are ${sub_hl}ON${__s}." \
		|| info "Subtitles are ${sub_hl}OFF${__s}."
	[ -v rc_default_audio -a -v audio ] \
		&& audio_hl="${__g}" \
		|| audio_hl="${__b}"
	[ -v audio ] \
		&& info "Audio is ${audio_hl}ON${__s}." \
		|| info "Audio is ${audio_hl}OFF${__s}."
	[ -v scale ] && {
		[ "${rc_default_scale:-}" != "${scale:-}" ] && scale_hl=${__b}
		$info "Scaling to ${scale_hl}${scale}p${__s}."
	}
	[ -v crop ] && {
		crop_string="${__b}$crop_w×$crop_h${__s}, X:$crop_x, Y:$crop_y"
		info "Cropping to: $crop_string."
		info "Cropped range takes $crop_to_orig_total_px_ratio% of the cadre.
		      Applying bitrate multiplier ${__b}${__y}0.$(
		          [ $crop_to_orig_total_px_ratio -lt 10 ]     \
		              && echo "0$crop_to_orig_total_px_ratio"  \
		              || echo "$crop_to_orig_total_px_ratio"    )${__s}."
	}
	[ "$max_size" = "$max_size_default" ] \
		&& info "Size to fit into: $max_size (kilo=$kilo)." \
		|| info "Size to fit into: ${__b}$max_size${__s} (kilo=$kilo)."
	info "Original video bitrate: $orig_video_bitrate kbps."
	info "Duration: $duration_hms."
	[ -v ar_bitrate_correction ] \
		&& info "Detected 4:3 AR. Applying bitrate multiplier ${__b}${__y}0.75${__s}."
	return 0
}

fit_bitrate_to_filesize() {
	# As we may re-run, let’s operate on a local copy.
	local closest_lowres_index=$closest_lowres_index res cannot_fit
	info "Calculating, how we fit… "
	max_size_in_bytes=$max_size
	max_size_in_bytes=${max_size_in_bytes//k/*$kilo}
	max_size_in_bytes=${max_size_in_bytes//M/*$kilo*$kilo}
	max_size_in_bytes=${max_size_in_bytes//G/*$kilo*$kilo*$kilo}
	max_size_in_bytes=$(($max_size_in_bytes))
	max_size_bits=$((max_size_in_bytes*8))
	container_own_size_percents=${container_own_size%\%}
	container_own_size_bits=$((    max_size_bits
	                             * container_own_size_percents
	                             / 100                          ))

	 # Calculates the maximum amount of video bitrate, that fits
	#  into max_size. Works only on $vbitrate_bits and $abitrate_bits, hence
	#  no bitrate corrections, except for 100k decrement, should be
	#  used here.
	#  Returns: 0 if we found an appropriate video bitrate;
	#           1 otherwise.
	#
	recalc_vbitrate_and_maxfitting() {
		local audio_info
		[ -v audio ] && audio_info=" / $abitrate"
		recalc_bitrate 'vbitrate'
		infon "Trying $vbitrate_pretty$audio_info @"
		if [ -v scale ]; then
			# Forced scale
			echo -n "${scale}p.  "
		elif [ -v crop ]; then
			echo -n "Cropped.  "
		elif [ -v res ]; then
			# Going lowres
			echo -n "${res}p.  "
		else
			echo -n 'Native.  '
		fi
		if [ -v audio ]; then
			audio_track_size_bits=$((  duration_total_s * abitrate_bits  ))
		else
			audio_track_size_bits=0
		fi
		space_for_video_track=$((   max_size_bits
		                          - audio_track_size_bits
		                          - container_own_size_bits  ))

		max_fitting_vbitrate_bits=$((    space_for_video_track
		                               / duration_total_s       ))
		echo "Have space for $((max_fitting_vbitrate_bits/1000))k$audio_info."
		[ ! -v forced_vbitrate ] \
		&& [ -v orig_video_bitrate_bits ] \
		&& [ -v orig_codec_same_as_enc ] \
		&& [ $max_fitting_vbitrate_bits -gt $orig_video_bitrate_bits ] && {
			info "Can fit original $orig_video_bitrate kbps!"
			vbitrate=$orig_video_bitrate_bits
			recalc_bitrate 'vbitrate'
			return 0
		}
		return 0
	}

	 # General function to do needed arithmetic and create representations
	#  of the new value.
	#  $1 – variable name for reference. The value may contain [kMG] suffix.
	# [$2..n] – correction types: “aspect_ratio”, “crop” or “minimal_bitrate”.
	#  The variable, which name is passed as $1 is converted to bits,
	#  and its suffix is expanded. Then arithmetic corrections are applied.
	#  The result of this function is:
	#    1) The variable, which name was passed as $1, after all calculations
	#       are done, is returned back to the form with a “k” or “M” suffix.
	#       This maintains precise value, so 2132 won’t become just 2k.
	#    2) Another variable is created. To the name of the referenced vari-
	#       able added “_bits” and this variable maintains its precise
	#       numeric value. No suffix.
	#    3) A variable with “_pretty” added to the name of the referenced
	#       variable has a suffix form, but unlike the original variable,
	#       which contains the precise value, here the value is rounded
	#       to the nearest k or M suffix.
	#  Thus, 1) and 2) are for calculations and 3) is for pretty output
	#  to the user.
	#
	recalc_bitrate() {
		local varname="$1" correction_type var_pretty var_bits
		declare -n var=$varname
		var=${var//k/*1000}
		var=${var//M/*1000*1000}
		var=$(( $var ))
		shift  # positional parameters become correction types
		for correction_type in "$@"; do
			case "$correction_type" in
				aspect_ratio)
					var=$((var ${ar_bitrate_correction:-}))
					;;
				crop)
					var=$((var ${crop_bitrate_correction:-}))
					;;
				minimal_bitrate)
					var=$((var * ${minimal_bitrate_perc%\%} / 100 ))
					;;
			esac
		done
		# Setting _bits variable
		declare -g ${varname}_bits=$var
		# Setting _pretty variable for user’s output
		# M’s cut too much, seeing 2430k would be more informative, than “2M”.
		# “Is that 2000k or 2900k?” Those 900k make a difference.
		#
		# if [[ "$var" =~ .......$ ]]; then
		# 	var_pretty="$((var/1000000))M"
		# el
		if [[ "$var" =~ ....$ ]]; then
			var_pretty="$((var/1000))k"
		else
			var_pretty=$var
		fi
		declare -g ${varname}_pretty=$var_pretty
		# Now we can return $var (actual variable passed by reference)
		# to its suffix form.
		if [[ "$var" =~ 000000$ ]]; then
			var=${var%000000}M
		elif [[ "$var" =~ 000$ ]]; then
			var=${var%000}k
		fi
		return 0
	}

	 # When resolution profile is set initially or changes afterwards,
	#  this function is called to assign
	#    - desired_vbitrate  \
	#    - minimal_vbitrate  |_ to the values from the bitrate-resolution
	#    - desired_abitrate  |  profile specified via $1.
	#    - minimal_abitrate  /
	#  After the desired values, vbitrate and abitrate are set. They are the
	#  “working” values – max_fitting_vbitrate is calculated with them,
	#  and it is vbitrate, that’s checked against max_fitting_vbitrate.
	#  $1 – resolution, ${res}, e.g. 1080, 720, 576…
	#
	set_bitrates() {
		local res="$1" libname=${ffmpeg_vcodec//-vp9/}
		# If vbitrate or abitrate are already set,
		# that means they were forced though the command line.
		[ -v ${libname}_${res}p_desired_bitrate ] \
		&& [ ! -v forced_vbitrate ] \
		&& {
			declare -gn desired_vbitrate="${libname}_${res}p_desired_bitrate"
			recalc_bitrate 'desired_vbitrate' aspect_ratio crop
			info "${res}p: Setting desired vbitrate to $desired_vbitrate_pretty."
			vbitrate=$desired_vbitrate
			vbitrate_bits=$desired_vbitrate_bits
			minimal_vbitrate=$desired_vbitrate
			recalc_bitrate 'minimal_vbitrate' minimal_bitrate
			info "${res}p: Setting minimal vbitrate to $minimal_vbitrate_pretty."
		}
		[ -v audio ] \
		&& [ -v audio_${res}p_desired_bitrate ] \
		&& [ ! -v forced_abitrate ] \
		&& {
			declare -gn desired_abitrate="audio_${res}p_desired_bitrate"
			recalc_bitrate 'desired_abitrate'  # only to set _bits, actually
			info "${res}p: Setting desired abitrate to $desired_abitrate_pretty."
			abitrate=$desired_abitrate
			abitrate_bits=$desired_abitrate_bits
		}
		# Forced bitrates are already set,
		# we only need to calculate _bits variables for them.
		[ -v forced_vbitrate ] && recalc_bitrate 'vbitrate'
		[ -v forced_abitrate ] && recalc_bitrate 'abitrate'
		return 0
	}

	# For the second and next calls of fit_bitrate_to_filesize()
	increment_container_own_size() {
		local container_own_size_clean=${container_own_size%\%}
		((container_own_size_clean++))
		container_own_size="${container_own_size_clean}%"
		return 0
	}


	if [ -v scale ]; then
		set_bitrates $scale
	else
		set_bitrates $orig_height
	fi
	milinc
	recalc_vbitrate_and_maxfitting

	 # What can be done, if bitrates × duration do not fit max_size.
	#  I find this array a genius invention, the code was a mess without it.
	#
	declare -A our_options=(
		[seek_maxfit_here]=t  # until vbitrate hits minimal in the current
		                     # resolution profile
		[lower_resolution]=t  # change resolution profile
	)

	 # Are we already good?
	#  If not, can we scale to lower resolutions?
	#
	until [ $vbitrate_bits -le $max_fitting_vbitrate_bits ]; do
		[ -v forced_vbitrate ] && unset our_options[seek_maxfit_here]
		[ -v forced_scale ] && unset our_options[lower_resolution]
		# The flexibility of this code is amazing – we can have fixed
		#   audio bitrate set with, say, ab200k and still have vbitrate go
		#   round and around until the overall size fits to max_size!

		if [ -v our_options[seek_maxfit_here] ]; then
			if [    $max_fitting_vbitrate_bits -ge $minimal_vbitrate_bits  \
			     -a $max_fitting_vbitrate_bits -le $desired_vbitrate_bits  ]
			then
			     vbitrate=$max_fitting_vbitrate_bits
			     recalc_vbitrate_and_maxfitting
			else
				unset our_options[seek_maxfit_here]
			fi
		elif [ -v our_options[lower_resolution] ]; then
			if [ $closest_lowres_index -lt ${#lower_res_list[@]} ]; then
				res=${lower_res_list[closest_lowres_index]}
				mildrop
				info "Trying lower resolution ${res}p… "
				set_bitrates $res
				((closest_lowres_index++, 1))
				milinc
				our_options[seek_maxfit_here]=t
				recalc_vbitrate_and_maxfitting
			else
				# Lower resolutions are depleted.
				unset our_options[lower_resolution]
			fi
		else
			cannot_fit=t
		fi
	done

	mildrop
	[ -v cannot_fit ] && err "Cannot fit $duration_hms into $max_size."

	 # $res and $scale hold same numbers, but the purposes
	#  of these variables differ:
	#  - scale is a global parameter. It indicates forced scale from the
	#    command line. It passes through and goes straight to -vf key in
	#    ffmpeg.
	#  - res is a local variable. It lives only within the scope of this
	#    function and its nested functions. In fact, of all nested functions
	#    it is used only in calc_max_fitting_vbitrate() in the info() call.
	#    local res sets global scale, if scale wasn’t set beforehand.
	#
	[ -v res ] && scale=$res

	 # In case the new file will come out bigger than $max_size,
	#  and this function will be called again to recalculate
	#  $max_fitting_vbitrate_bits, increment $container_own_size,
	#  so that next time it’ll be 1% bigger.
	#
	increment_container_own_size
	return 0
}

print_encoding_info() {
	local encinfo
	# Bright (bold) white for command line overrides.
	# Yellow for automatic scaling.
	encoding_info="Encoding with "
	[ -v forced_vbitrate ] \
		&& encoding_info+="${__b}$vbitrate${__s} " \
		|| encoding_info+="$vbitrate_pretty "
	encoding_info+='/ '
	[ -v audio ] && {
		[ -v forced_abitrate ] \
			&& encoding_info+="${__b}$abitrate${__s} " \
			|| encoding_info+="$abitrate "
	}
	encoding_info+='@'
	if [ -v forced_scale ]; then
		encoding_info+="${__b}${scale}p${__s}"
	elif [ -v scale ]; then
		encoding_info+="${__b}${__y}${scale}p${__s}"
	elif [ -v crop ]; then
		encoding_info+="Cropped"
	else
		encoding_info+='Native'
	fi
	[ -v subs ] || encoding_info+=", ${__b}nosubs${__s}"
	[ -v audio ] || encoding_info+=", ${__b}noaudio${__s}"
	encoding_info+='.'
	info  "$encoding_info"
	return 0
}

assemble_vf_string() {
	local filter_list= id font_name
	[ -v scale ] || [ -v subs ] || [ -v crop ] && {
		[ -v subs ] && {
			info "Extracting subs and fonts."
			# Extracting subs and fonts.
			# Let’s hope that the source is mkv and the subs are ass.
			[ -d "$TMPDIR/fonts" ] || mkdir "$TMPDIR/fonts"
			FFREPORT=file=$LOGDIR/ffmpeg-extraction-subs.log:level=32 \
			$ffmpeg -y -hide_banner -i "$video" -map 0:s:0 "$TMPDIR/subs.ass"
			while read -r ; do
				id=${REPLY%$'\t'*}
				font_name=${REPLY#*$'\t'}
				mkvextract attachments \
				           "$video" $id:"$TMPDIR/fonts/$font_name" \
				           &>"$LOGDIR/mkvextract.log"
			done < <(mkvmerge -i "$video" \
			         | sed -rn "s/Attachment ID ([0-9]+):.*\s+'(.*)(ttf|TTF|otf|OTF)'$/\1\t\2\3/p")
			filter_list="${filter_list:+$filter_list,}"
			filter_list+="setpts=PTS+$((start_total_ms/1000)).$start_ms/TB,"
			filter_list+="subtitles=$TMPDIR/subs.ass:fontsdir=$TMPDIR/fonts,"
			filter_list+='setpts=PTS-STARTPTS'
		}
		[ -v crop ] && {
			filter_list="${filter_list:+$filter_list,}"
			filter_list+="$crop"
		}
		[ -v scale ] && {
			filter_list="${filter_list:+$filter_list,}"
			filter_list+="scale=-2:$scale"
		}
		vf_string="-vf $filter_list"
	}
	return 0
}

encode-libx264() {
	info 'PASS 1'
	FFREPORT=file=$LOGDIR/ffmpeg-pass1.log:level=32 \
	$ffmpeg -y  -ss "$start"  -to "$stop"  -i "$video" \
	        $vf_string \
	        -c:v $ffmpeg_vcodec -pix_fmt $ffmpeg_pix_fmt \
	            -b:v $vbitrate_bits \
	                -maxrate $vbitrate_bits \
	                -bufsize $((2*vbitrate_bits)) \
	            -preset:v $libx264_preset -tune:v $libx264_tune \
	            -profile:v $libx264_profile -level $libx264_level \
	        -pass 1 -an \
	        -f $container_format /dev/null

	info 'PASS 2'
	FFREPORT=file=$LOGDIR/ffmpeg-pass2.log:level=32 \
	$ffmpeg -y  -ss "$start"  -to "$stop"  -i "$video" \
	        $vf_string \
	        -c:v $ffmpeg_vcodec -pix_fmt $ffmpeg_pix_fmt \
	            -b:v $vbitrate_bits \
	                -maxrate $vbitrate_bits \
	                -bufsize $((2*vbitrate_bits)) \
	            -preset:v $libx264_preset -tune:v $libx264_tune \
	            -profile:v $libx264_profile -level $libx264_level \
	        -pass 2 \
	        $audio \
	        ${faststart:-} \
	        "$new_file_name"

	return 0
}

encode-libvpx-vp9() {
	local encoding_res tile_column_min_width=256
	log2() {
		local x=$1 n=2 l=-1
		while ((x)); do ((l+=1, x/=n, 1)); done
		echo $l
	}
	[ -v libvpx_adaptive_tile_columns ] && {
		if [ -v scale ]; then
			encoding_res=$scale
			if [ "$orig_ar" = '4:3' ]; then
				scaled_width=$((  (scale*4/3)/2*2  ))
				libvpx_tile_columns=$((    scaled_width
				                         / tile_column_min_width  ))
			elif [ "$orig_ar" = '16:9' ]; then
				scaled_width=$((  (scale*16/9)/2*2  ))
				libvpx_tile_columns=$((    scaled_width
				                         / tile_column_min_width  ))
			else
				libvpx_tile_columns=1
			fi
		elif [ -v crop ]; then
			libvpx_tile_columns=$((    crop_w
			                         / tile_column_min_width  ))
		else
			# Native resolution
			libvpx_tile_columns=$((    orig_width
			                         / tile_column_min_width  ))
		fi
		# Videos with a width smaller than $tile_column_min_width
		# as well as cropped ones will result in 0 tile-columns
		# and log2(0) will return -1, while it should still return 0.
		[ $libvpx_tile_columns -eq 0 ] && libvpx_tile_columns=1
		# tile-columns should be a log2(actual number of tile-columns)
		libvpx_tile_columns=$(log2 $libvpx_tile_columns)
		# Docs on Google Devs count threads as tile-columns*2 for resolutions
		# under 2160p, i.e. give a minimum of two threads per one tile.
		libvpx_threads=$((2**libvpx_tile_columns*2))
	}

	info 'PASS 1'

	FFREPORT=file=$LOGDIR/ffmpeg-pass1.log:level=32 \
	$ffmpeg -y  -ss "$start"  -to "$stop"  -i "$video" \
	        $vf_string \
	        -c:v $ffmpeg_vcodec -pix_fmt $ffmpeg_pix_fmt \
	            -crf $libvpx_crf -b:v $vbitrate_bits \
	                             -minrate $((vbitrate_bits/2)) \
	                             -maxrate $vbitrate_bits \
	            -undershoot-pct 0 -overshoot-pct 0 \
	            -frame-parallel $libvpx_frame_parallel \
	                -tile-columns $libvpx_tile_columns \
	                    -threads $libvpx_threads \
	            -deadline $libvpx_pass1_deadline \
	                -cpu-used $libvpx_pass1_cpu_used \
	            -auto-alt-ref $libvpx_auto_alt_ref \
	                -lag-in-frames $libvpx_lag_in_frames \
	            -g $libvpx_keyint_max \
	        -pass 1 -an -sn \
	        -f $container_format /dev/null

	info 'PASS 2'

	FFREPORT=file=$LOGDIR/ffmpeg-pass2.log:level=32 \
	$ffmpeg -y  -ss "$start"  -to "$stop"  -i "$video" \
	        $vf_string \
	        -c:v $ffmpeg_vcodec -pix_fmt $ffmpeg_pix_fmt \
	            -crf $libvpx_crf -b:v $vbitrate_bits \
	                             -minrate $((vbitrate_bits/2)) \
	                             -maxrate $vbitrate_bits \
	            -undershoot-pct 0 -overshoot-pct 0 \
	            -frame-parallel $libvpx_frame_parallel \
	                -tile-columns $libvpx_tile_columns \
	                    -threads $libvpx_threads \
	            -deadline $libvpx_pass2_deadline \
	                -cpu-used $libvpx_pass2_cpu_used \
	            -auto-alt-ref $libvpx_auto_alt_ref \
	                    -lag-in-frames $libvpx_lag_in_frames \
	            -g $libvpx_keyint_max \
	        -pass 2 \
	        $audio \
	        -sn \
	        "$new_file_name"
	return 0
}

encode() {
	local vf_string encode_func faststart container_format
	declare -g new_file_name="${video%.*} $start–$stop.$container"
	new_file_name="$where_to_place_new_file/${new_file_name##*/}"
	print_encoding_info
	milinc
	set +f
	rm -f "$LOGDIR/"ffmpeg*  "$LOGDIR/"mkvextract*  "$LOGDIR/time_output"
	set -f
	assemble_vf_string
	[ -v time_stat -a ! -v time_applied ] && {
		# Could be put in set_vars, but time is better to be applied after
		# $vf_string is assembled, or we get conditional third time.
		ffmpeg="$(which time) -f %e -o $LOGDIR/time_output -a $ffmpeg"
		time_applied=t
	}
	[ -v audio ] \
		&& audio="-c:a $ffmpeg_acodec -b:a $abitrate" \
		|| audio='-an'
	case "$container" in
		# mkv)
		# 	# “webm” can be a container format, but “mkv” cannot. Weird.
		# 	container_format='matroska'
		#   novttsubs="-sn"
		# 	;;
		webm)
			container_format=$container
			;;
		mp4)
			container_format=$container
			faststart='-movflags +faststart'
			;;
	esac
	encode_func=$(type -t encode-$ffmpeg_vcodec)  \
	&& [ "$encode_func" = 'function' ]  \
	&& encode-$ffmpeg_vcodec
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
	pass1_hms=$(get_duration_hms $pass1_s pad)
	pass2_hms=$(get_duration_hms $pass2_s pad)
	pass1_and_pass2_hms=$(get_duration_hms $pass1_and_pass2_s pad)
	speed_ratio=$(echo "scale=2; $pass1_and_pass2_s/$duration_total_s" | bc)
	speed_ratio="${__b}${__y}$speed_ratio${__s}"
	info "Stats:
	      Pass 1 – $pass1_hms.
	      Pass 2 – $pass2_hms.
	       Total – $pass1_and_pass2_hms.
	      Encoding took $speed_ratio× time of the file duration."
	return 0
}

parse_args "$@"
set_vars
check_util_support video ${audio:+audio} ${subs:+subs} ${time_stat:+time_stat}
display_settings
until [ $(stat --printf %s "${new_file_name:-/dev/null}") \
        -le ${max_size_in_bytes:--1} ]; \
do
	fit_bitrate_to_filesize
	encode
done
info-ns "Encoded successfully."
info "${new_file_name##*/}"
[ -v time_stat ] && print_stats
which xclip &>/dev/null && {
	echo -n "$new_file_name" | xclip
	info 'Copied path to clipboard.'
}
[ -v pedantic ] && comme_il_faut_check "$new_file_name"
exit 0
