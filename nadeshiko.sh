#! /usr/bin/env bash

# nadeshiko.sh
#   A shell script to cut small videos with ffmpeg.
#   deterenkelt © 2018

# This program is free software; you can redistribute it and/or modify it
#   under the terms of the GNU General Public License as published
#   by the Free Software Foundation; either version 3 of the License,
#   or (at your option) any later version.
# This program is distributed in the hope that it will be useful,
#   but without any warranty; without even the implied warranty
#   of merchantability or fitness for a particular purpose.
#   See the GNU General Public License for more details.

set -feE
shopt -s extglob
declare -r BHLLS_LOGGING_ON=t
. "$(dirname "$0")/bhlls.sh"

declare -r RC_FILE="$MYDIR/nadeshiko.rc.sh"
declare -r VERSION='20180303'
declare -r MY_MSG_TITLE='Nadeshiko'
where_to_place_new_file=$PWD

 # Default values. Edit nadeshiko.rc.sh to override them.
#
#  Output container format.
#  Theoretically it’s possible to use mkv.
container=mp4
#
#  Maximum size for the encoded file.
#  [kMG] suffixes use powers of 2, unless $kilo is set to 1000.
max_size_default=20M
#
#  Pass “small” to the command line parameter,
#  to override max_size_default with the value specified below.
max_size_small=10M
#
#  Pass “tiny” to the command line parameter,
#  to override max_size_default with the value specified below.
max_size_tiny=2M
#
#  For manual control and experiments. Intended to be used
#  along with vbNNNN, abNNNN and XXXp.
declare -r max_size_unlimited=99999M
#
#  Multiplier for max_size “k” “M” “G” suffixes. Can be 1024 or 1000.
#  Reducing this value may solve the problem with videos not uploading,
#  because file size limit uses powers of 10 (10, 100, 1000…)
kilo=1024
#
#  Space required for the container header and footer.
#  The value is a percent of the maximum allowed file size, e.g. “1%”, “5%”.
container_own_size=2%
#
#  Default video bitrate (fallback for dumb mode, shouldn’t be used).
vbitrate=1500k
#
#  Default audio bitrate (fallback for dumb mode, shouldn’t be used).
abitrate=98k


 # Default encoder options
#
#  Do not spam to console
#  (ffmpeg logs are still on the info level).
ffmpeg='ffmpeg -v error'
#
#  Maximum compatibility.
ffmpeg_pix_fmt='yuv420p'
#
#  Good quality/file size ratio, optimum speed/quality encoding.
ffmpeg_vcodec='libx264'
#
#  Quality > speed, obviously.
ffmpeg_preset='veryslow'
#
#  Best quality from the preset.
ffmpeg_tune='film'
#
#  Compatibility again,
ffmpeg_profile='high'
#
#  …and again,
ffmpeg_level='4.2'
#
#  …and again.
ffmpeg_acodec='aac'


 # Default bitrate-resolution profiles.
#  Desired bitrate is the one we aim to have, and the minimal is the lowest
#  on which we agree.
#
#  To find the balance between resolution and quality,
#  nadeshiko.sh offers three modes:
#  - dumb mode: use default values of max_size and abitrate, ignore vbitrate
#    and fit as much video bitrate as max_size allows.
#  - intelligent mode: operates on desired and minimal bitrate,
#    can lower resolution to preserve more quality. Requires the table
#    of resolutions and bitrates to be present (it is found right below),
#  - forced mode: this mode is set by the commandline options, that force
#    scale and bitrates for audio/video.
#    forced > intelligent > dumb
#
video_360p_desired_bitrate=500k
video_360p_minimal_bitrate=220k
audio_360p_bitrate=80k
#
video_480p_desired_bitrate=1000k
video_480p_minimal_bitrate=400k
audio_480p_bitrate=80k
#
video_576p_desired_bitrate=1500k
video_576p_minimal_bitrate=720k
audio_576p_bitrate=98k
#
video_720p_desired_bitrate=2000k
video_720p_minimal_bitrate=800k
audio_720p_bitrate=112k
#
video_1080p_desired_bitrate=3500k
video_1080p_minimal_bitrate=1500k
audio_1080p_bitrate=128k
#
 # By default, burn subtitles into video.
#  Override with “nosubs” on command line
#  or put “unset subs” in the RC file.
#
subs=t

 # Reading the RC file.
#
if [ -r "$RC_FILE" ]; then
	. "$RC_FILE"
else
	warn "$RC_FILE not found! Built-in defaults will be used."
fi

show_help() {
	cat <<-EOF
	Usage
	./nadeshiko.sh  <start_time> <stop_time> [OPTIONS] <source video>

	Required options
	         start_time – Time from the beginning of <source video>.
	          stop_time   Any formats are possible:
	                      01:23:45:670   = 1 h 23 min 45 s 670 ms
	                         23:45.1     = 23 min 45 s 100 ms
	                             5       = 5 s
	                      Padding zeroes aren’t required.
	       source video – Path to the source videofile.

	Other options
	      nosub, nosubs – make a clean video, without hardsubs.
	            noaudio – make a mute video.
	                 si – when converting kMG suffixes of the maximum
	                      file size, use powers 1000 instead of 1024.
	          <format>p – force encoding to the specified resolution,
	                      <format> is one of: 1080, 720, 576, 480, 360.
	       small | tiny – override the default maximum file size (20M).
	        | unlimited   Values must be set in nadeshiko.rc.sh beforehand.
	                      Default presets are: small=10M, tiny=2M.
	    vb<number>[kMG] – force video bitrate to specified <number>.
	                      A suffix may be applied: vb300000, vb1200k, vb2M.
	      ab<number>[k] – force audio bitrate the same way.
	                      Example: ab128000, ab192k, ab88k.
	           <folder> – place encoded file in the <folder>.

	The order of options is unimportant. Throw them in,
	Nadeshiko will do her best.

	https://github.com/deterenkelt/Nadeshiko
	EOF
	exit 0
}

show_version() {
	cat <<-EOF
	nadeshiko.sh $VERSION
	© deterenkelt 2018.
	Licence GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
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
			common)
				required_utils+=(
					# For encoding. 3.4.2+ recommended.
					ffmpeg
					# To get source video resolution.
					ffprobe
					# To get source video bit rate. ffprobe shows only N/A.
					mediainfo
				)
				;;
			subs)
				required_utils+=(
					# To get the list of attachments in the source video.
					mkvmerge
					# To extract subtitles and fonts from the source video.
					# (subtitles are needed for hardsubbing, and hardsub.
					# will be poor without built-in fonts).
					mkvextract
				)
				;;
		esac
	done
	check_required_utils || err "Missing dependencies."
	codec_list=$($ffmpeg -hide_banner -codecs)
	for arg in "$@"; do
		case "$arg" in
			common)
				grep -qE "\s.EV... .*encoders:.*$vcodec" <<<"$codec_list" || {
					warn "$ffmpeg doesn’t support $vcodec encoder!"
					missing_encoders=t
				}
				grep -qE "\s.EA... .*encoders:.*$acodec" <<<"$codec_list" || {
					warn "$ffmpeg doesn’t support $acodec encoder!"
					missing_encoders=t
				}
				;;
			subs)
				grep -qE "\s.ES... ass" <<<"$codec_list" || {
					warn "$ffmpeg doesn’t support encoding ASS subtitles!"
					missing_encoders=t
				}
				;;
		esac
	done
	[ -v missing_encoders ] \
		&& err "Support for requested encoders is missing in ffmpeg!"
	return 0
}

 # Cut a short video.
#  Parameters:
#  <source video file>
#  <start time>
#  <stop time>
#  [nosub|nosubs] – if hardsub is not needed. Will save encoding time.
#  [noaudio] – if audio isn’t needed. Will save bitrate for video.
#  [<small>|<tiny>] to override max_size (see the RC file).
#  [<vb|ab><bitrate>[kMG]] – force specified bitrate, ignoring the defaults
#       and desired/minimal values from RC file.
#       Example: vb2M, vb1700k, ab192k.
#  [si] – override kilo=1024 from the RC file.
#  [path where to place new file] – override placement in the directory,
#       from which Nadeshiko is called.
#  ^
#  ╰­----The order is unimportant.
#       Just throw the keys on the command line, Nadeshiko will do her best.
#
parse_args() {
	args=("$@")
	for arg in "${args[@]}"; do
		if [[ "$arg" = @(-h|--help) ]]; then
			show_help
		elif [[ "$arg" = @(-v|--version) ]]; then
			show_version
			#                /hours\       /minutes\      /seconds\    /mseconds\
		elif [[ "$arg" =~ ^(([0-9]{1,2}:|)([0-9]{1,2}:)|)([0-9]{1,2})(\.[0-9]{1,3}|)$ ]]; then
			#                           ^           ^  ^          ^
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
				time2_total_ms=$((   ${time2_h#0}*3600000  \
				                   + ${time2_m#0}*60000    \
				                   + ${time2_s#0}*1000     \
				                   + ${time2_ms##@(0|00)}  \
				                ))
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
				time1_total_ms=$((   ${time1_h#0}*3600000  \
				                   + ${time1_m#0}*60000    \
				                   + ${time1_s#0}*1000     \
				                   + ${time1_ms##@(0|00)}  \
				                ))
				time1="$time1_h:$time1_m:$time1_s.$time1_ms"
			fi
		elif [[ "$arg" =~ ^nosubs?$ ]]; then
			unset subs
		elif [ "$arg" = noaudio ]; then
			audio="-an"
		elif [ "$arg" = si ]; then
			kilo=1000
		elif [[ "$arg" =~ ^(360|480|576|720|1080)p$ ]]; then
			# $res and $scale variables are quite similar,
			#   but their purpose differs:
			# $res maintains a value that tells what resolution we are
			#   /currently/ aiming at – it may change during the process
			#   of finding a winning bitrate/resolution combination.
			# $scale serves as a flag, that we need ffmpeg’s “scale”
			#   filter and copies value from res.
			mode='forced'
			res="${BASH_REMATCH[1]}"
			declare -gn scale=res
		elif [[ "$arg" =~ ^(tiny|small)$ ]]; then
			declare -gn max_size="max_size_$arg"
		elif [[ "$arg" =~ ^(vb|ab)([0-9]+[kMG])$ ]]; then
			mode='forced'
			[ "${BASH_REMATCH[1]}" = vb ] && {
				vbitrate="${BASH_REMATCH[2]}"
				forced_vbitrate=t
			}
			[ "${BASH_REMATCH[1]}" = ab ] && {
				abitrate="${BASH_REMATCH[2]}"
				forced_abitrate=t
			}
		elif [ -f "$arg" ]; then
			video="$arg"
		elif [ -d "$arg" ]; then
			if [ -w "$arg" ]; then
				where_to_place_new_file="$arg"
			else
				err "Command line specified directory “$arg” for the new file,
				     but it is not writeable."
			fi
		else
			err "“$arg”: parameter unrecognised."
		fi
	done
	[ "$mode" = forced ] && declare -gn max_size="max_size_unlimited"
	[ -v video ] && [ -v time1 ] && [ -v time2 ] \
	&& [ $time1_total_ms -ne $time2_total_ms ] \
		|| err "Set video file, start time and stop time!"
	# [ -v scale ] || [ -v forced_vbitrate ] || [ -v forced_abitrate ] && {
	# 	[ -v scale ] && [ -v forced_vbitrate -a -v forced_abitrate ] || {
	# 		err "Forced mode requires all three settings to be set:
	# 		     vb0000k – video bitrate
	# 		     abXXXk – audio bitrate
	# 		     XXXXp – scale"
	# 	}
	# }
	return 0
}

set_vars() {
	[ -v max_size ] || declare -g max_size=$max_size_default
	if [ "$time2_total_ms" -gt "$time1_total_ms" ]; then
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
	duration_h=$((duration_total_s/3600))
	duration_m=$(( (duration_total_s - duration_h*3600) /60))
	duration_s=$(( (duration_total_s - duration_h*3600 - duration_m*60) ))
	duration_hms="$duration_h:$duration_m:$duration_s"
	# Getting the original video and audio bitrate.
	orig_video_bitrate=$(
		mediainfo "$video" \
    		| sed -nr '/^Video$/,/^$/ {
    	                                s/^Nominal bit rate\s+:\s([0-9 ]+).*/\1/
	                                    T
	                                    s/\s+//gp
	                                  }'
	    )
	# Somewhere here we should check the units,
	# that mediainfo uses. Is kbps used always?
	if [[ "$orig_video_bitrate" =~ ^[0-9]+$ ]]; then
		orig_video_bitrate_bits=$((orig_video_bitrate*1000))
		info "Original video bitrate: $orig_video_bitrate kbps"
	else
		warn 'Couldn’t retrieve bitrate of the original video.'
		no_orig_video_bitrate=t
	fi

	info "Size to fit into: $max_size (kilo=$kilo)"
	info "Duration: $duration_hms"

	read -d '' orig_width orig_height \
		< <( ffprobe -hide_banner -v error -select_streams v:0 \
	                 -show_entries stream=width,height \
	                 -of default=noprint_wrappers=1:nokey=1 \
	                 "$video"; \
	         echo -e '\0'  )
	[[ "$orig_width" =~ ^[0-9]+$ && "$orig_height" =~ ^[0-9]+$ ]] && {
		# Since in our tables desireable/minimal bitrates are given
		# for 16:9 aspect ratio, 4:3 video would require on 25% less
		# bitrate, as there’s 25% less pixels.
		# 4÷3 ≈ 1.3333
		# 16÷9 ≈ 1.7777
		# Let’s hope there won’t be an ultra-wide 18×9.
		# Actual sizes may vary, so even with bc we’d still
		# have to fiddle with 1.333 ±0.15
		[ $((orig_width % orig_height)) -lt 5 ] && {
			dar_bitrate_correction='*3/4'
			info "Applying bitrate multiplier 0.25 for 4:3 video."
		}
		have_orig_res=t
		# [ -v res ] || res=$orig_height
	}
	lower_res_list=( 1080 720 576 480 360 )  # for the intelligent mode.
	for ((i=0; i<${#lower_res_list}; i++ )); do
		# If a table resolution is greater than or equal
		#   to the source video height, such resolution isn’t
		#   actually lower, and we don’t need upscales.
		# If we intend to scale down the source and the desired
		#   resolution if higher than table resolution,
		#   again, it should be skipped.
		[ -v orig_height ] \
			&& [ ${lower_res_list[i]} -ge $orig_height ] \
			&& ((closest_lowres_index++, 1))
		[ -v res ] \
			&& [ ${lower_res_list[i]} -gt $res ] \
			&& ((closest_lowres_index++, 1))
	done
	# Nadeshiko downscales the source video only if needed,
	# and the first jump to a lower resolution happens further
	# in the code. We don’t need to set that index now.
	((closest_lowres_index--, 1))
	return 0
}

fit_bitrate_to_filesize() {
	info "Calculating, how we fit… "
	max_size_in_bytes=$max_size
	max_size_in_bytes=${max_size_in_bytes//k/*$kilo}
	max_size_in_bytes=${max_size_in_bytes//M/*$kilo*$kilo}
	max_size_in_bytes=${max_size_in_bytes//G/*$kilo*$kilo*$kilo}
	max_size_in_bytes=$(($max_size_in_bytes))
	max_size_in_bits=$(($max_size_in_bytes*8))
	container_own_size_percents=${container_own_size%\%}
	container_own_size_in_bits=$(( max_size_in_bits              \
	                               * container_own_size_percents  \
	                               / 100                          ))
	 # Calculates the maximum amount of video bitrate,
	#  that fits into max_size.
	#
	#  Works only on $vbitrate and $abitrate.
	#
	calc_max_fitting_vbitrate() {
		vbitrate_in_bits=$vbitrate
		vbitrate_in_bits=${vbitrate_in_bits//k/*1000}
		vbitrate_in_bits=${vbitrate_in_bits//M/*1000*1000}
		vbitrate_in_bits=$((  $vbitrate_in_bits       \
		                      $dar_bitrate_correction  \
		                      - ${decrement:-0}        ))

		infon "Trying $((vbitrate_in_bits/1000))k / $abitrate @"
		[ -v res ] && echo -n "${res}p.  " || echo -n 'Native.  '

		[ "$audio" = '-an' ] \
			&& audio_track_size_in_bits=0 \
			|| audio_track_size_in_bits=$(( (duration_total_s+1) \
			                                * abitrate_in_bits   ))

		space_for_video_track=$(( max_size_in_bits            \
		                          - audio_track_size_in_bits   \
		                          - container_own_size_in_bits ))

		max_fitting_video_bitrate=$((  space_for_video_track  \
		                               / (duration_total_s+1) ))

		 # Here is a temptation to make a shortcut:
		#  assign max_fitting…bitrate to vbitrate, and we’ll jump
		#  right ahead to the next resolution. Ha! No.
		#  Making this shortcut properly needs more time,
		#  which I don’t have atm.
		#
		# vbitrate_in_bits=$max_fitting_video_bitrate
		# vbitrate=$((max_fitting_video_bitrate/1000))k
		echo "Have space for $((max_fitting_video_bitrate/1000))k / $abitrate."
		# If we know the bitrate of the original file,
		# prevent exceeding its value.
		[ "$mode" != forced ] && {
			[ -v orig_video_bitrate_bits ] \
				&& [ $max_fitting_video_bitrate \
				     -gt $orig_video_bitrate_bits ] && {
			  	info "Can fit original $orig_video_bitrate kbps!"
			  	info "Restricting maximum video bitrate to $orig_video_bitrate kbps."
			  	max_fitting_video_bitrate=$orig_video_bitrate_bits
			  	vbitrate_in_bits=$orig_video_bitrate_bits
			  	vbitrate=$((vbitrate_in_bits/1000))k
			}
		}
		return 0
	}

	 # Pick desired and minimal bitrates from the table.
	#  $1 – resolution, ${res}, e.g. 1080, 720 576…
	#
	set_new_bitrates() {
		local res="$1"
		[ -v video_${res}p_desired_bitrate ] && {
			declare -gn desired_vbitrate="video_${res}p_desired_bitrate"
			info "${res}p: Setting desired vbitrate to $desired_vbitrate."
			desired_vbitrate_in_bits=$desired_vbitrate
			desired_vbitrate_in_bits=${desired_vbitrate_in_bits//k/*1000}
			desired_vbitrate_in_bits=${desired_vbitrate_in_bits//M/*1000*1000}
			desired_vbitrate_in_bits=$(( $desired_vbitrate_in_bits \
			                             $dar_bitrate_correction   ))
		}
		[ -v video_${res}p_minimal_bitrate ] && {
			declare -gn minimal_vbitrate="video_${res}p_minimal_bitrate"
			info "${res}p: Setting minimal vbitrate to $minimal_vbitrate."
			minimal_vbitrate_in_bits=$minimal_vbitrate
			minimal_vbitrate_in_bits=${minimal_vbitrate_in_bits//k/*1000}
			minimal_vbitrate_in_bits=${minimal_vbitrate_in_bits//M/*1000*1000}
			minimal_vbitrate_in_bits=$(( $minimal_vbitrate_in_bits \
			                             $dar_bitrate_correction   ))
		}
		[ -v audio_${res}p_bitrate ] && {
			declare -gn abitrate="audio_${res}p_bitrate"
			info "${res}p: Setting abitrate to $abitrate."
			abitrate_in_bits=$abitrate
			abitrate_in_bits=${abitrate_in_bits//k/*1000}
			abitrate_in_bits=${abitrate_in_bits//M/*1000*1000}
			abitrate_in_bits=$(($abitrate_in_bits))
		}
		return 0
	}

	# For the second and next calls of fit_bitrate_to_filesize()
	increment_container_own_size() {
		local container_own_size_clean=${container_own_size%\%}
		((container_own_size_clean++))
		container_own_size="${container_own_size_clean}%"
		return 0
	}

	if [ "$mode" = forced ]; then
		# Nothing to do. $vbitrate and $abitrate are already set,
		# $scale isn’t related to calculations and applies separately.
		:
	else
		if [ -v have_orig_res ]; then
			mode='intelligent'
			# Enabling intelligent mode.
			# Trying from the desired bitrate in the current resolution
			# lowering it by 100k until it fits max_size or the minimal value
			# is reached. Then if it’s allowed to go for a lower resolution,
			# switch desirable and minimal resolutions to it and repeat.
			set_new_bitrates $orig_height
			vbitrate="$desired_vbitrate"
		else
			mode='dumb'
			# Dumb mode.
			# If ffprobe couldn’t get original resolution, Nadeshiko
			# can only try to fit as much as possible, if only
			# what’s possible is not below some sane range.
			#
			# Repeating the default here, vbitrate and abitrate at the top
			# will probably be deleted in the future in favour of the table.
			# This is probably the only case, when the default $abitrate
			# in needed.
			abitrate=98k
			vbitrate=12000k
		fi
	fi
	milinc
	calc_max_fitting_vbitrate

	# First resolution, then – bitrate.
	# We want to find not some vbitrate, that would be lower than what fits
	#   in the container. We know that max_fitting_vitrate and it doesn’t
	#   change unless we scale down.
	# We seek for a resolution, that would look adequately with the bitrate,
	#   that we’re allowed in the file size.
	until [ $vbitrate_in_bits -le $max_fitting_video_bitrate ]; do
		case "$mode" in
			forced)
				# User forced these bitrates intentionally.
				# Cannot do anything else.
				cannot_fit=t
				break
				;;
			intelligent)
				# Can we lower a bitrate slightly, but remain in the span
				# of minimal…desired bitrates for the current ${res}olution?
				#
				# While the bitrate we test can be lowered by 100k, lower it.
				if [ $((vbitrate_in_bits-100000)) -ge $minimal_vbitrate_in_bits ]; then
					let decrement+=100000
					calc_max_fitting_vbitrate
				else
					# Go down one resolution lower
					((closest_lowres_index++, 1))
					if [ $closest_lowres_index -lt ${#lower_res_list[@]} ]; then
						res=${lower_res_list[closest_lowres_index]}
						declare -gn scale=res
						mildrop
						info "Trying lower resolution ${res}p… "
						set_new_bitrates $res
						vbitrate="$desired_vbitrate"
						unset decrement
						milinc
						calc_max_fitting_vbitrate
					else
						# Lower resolutions are depleted.
						cannot_fit=t
						break
					fi

				fi
				;;
			dumb)
				[ $max_fitting_video_bitrate -lt 200000 ] && cannot_fit=t
				break
				;;
		esac
	done
	mildrop
	[ -v cannot_fit ] && err "Cannot fit $duration_hms into $max_size."
	[ "$mode" = forced ] && max_fitting_video_bitrate="$vbitrate_in_bits"
	#  In case the new file will come out bigger than $max_size,
	#  and this function will be called again to recalculate
	#  $max_fitting_video_bitrate, increment $container_own_size,
	#  so that next time it’ll be 1% bigger.
	increment_container_own_size
	return 0
}


encode() {
	local encoding_info
	declare -g new_file_name="${video%.*} $start–$stop.$container"
	new_file_name="$where_to_place_new_file/${new_file_name##*/}"
	encoding_info="Encoding with $((max_fitting_video_bitrate/1000))k "
	encoding_info+="/ $abitrate @"
	[[ "$res" =~ ^[0-9]+$ ]] \
		&& encoding_info+="${res}p" \
		|| encoding_info+='Native'
	[ "$mode" = forced ] && encoding_info+=' (forced)'
	encoding_info+='.'
	info  "$encoding_info"
	milinc

	set +f
	rm -f "$LOGDIR/"ffmpeg*  "$LOGDIR/"mkvextract*  #  Remove old ffmpeg logs.
	set -f

	[ -v scale -o -v subs ] && {
		# If we do hardsubbing or scaling, we need to assemble -vf string.
		[ -v scale ] && {
			filter_list="scale=-2:$scale"
		}
		[ -v subs ] && {
			info "Extracting subs and fonts."
			# Extracting subs and fonts.
			# Let’s hope that the source is mkv and the subs are ass.
			[ -d "$TMPDIR/fonts" ] || mkdir "$TMPDIR/fonts"
			FFREPORT=file=$LOGDIR/ffmpeg-extraction-subs.log:level=32 \
			$ffmpeg -hide_banner -i "$video" -map 0:s "$TMPDIR/subs.ass"
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
		vf_string="-vf $filter_list"
	}

	info 'PASS 1'

	FFREPORT=file=$LOGDIR/ffmpeg-pass1.log:level=32 \
	$ffmpeg -y  -ss "$start"  -to "$stop"  -i "$video" \
	        $vf_string \
	        -c:v $ffmpeg_vcodec -pix_fmt $ffmpeg_pix_fmt \
	            -b:v $max_fitting_video_bitrate \
	            -maxrate $max_fitting_video_bitrate \
	            -bufsize $((2*max_fitting_video_bitrate)) \
	            -preset:v $ffmpeg_preset -tune:v $ffmpeg_tune \
	            -profile:v $ffmpeg_profile -level $ffmpeg_level \
	            -pass 1 -an \
	        -f $container /dev/null

	info 'PASS 2'

	FFREPORT=file=$LOGDIR/ffmpeg-pass2.log:level=32 \
	$ffmpeg -y  -ss "$start"  -to "$stop"  -i "$video" \
	        $vf_string \
	        -c:v $ffmpeg_vcodec -pix_fmt $ffmpeg_pix_fmt \
	            -b:v $max_fitting_video_bitrate \
	            -maxrate $max_fitting_video_bitrate \
	            -bufsize $((2*max_fitting_video_bitrate)) \
	            -preset:v $ffmpeg_preset -tune:v $ffmpeg_tune \
	            -profile:v $ffmpeg_profile -level $ffmpeg_level \
	            -pass 2 \
	        ${audio:--c:a $ffmpeg_acodec -b:a $abitrate} \
	        -movflags +faststart \
	        "$new_file_name"

	rm -f ffmpeg2pass-0.log ffmpeg2pass-0.log.mbtree
	mildec
	return 0
}


parse_args "$@"
check_util_support common ${subs:+subs}
set_vars
until [ $(stat --printf %s "${new_file_name:-/dev/null}") \
        -le ${max_size_in_bytes:--1} ]; \
do
	fit_bitrate_to_filesize
	encode
done
info-ns "Encoded successfully."
info "${new_file_name##*/}"
which xclip &>/dev/null && {
	echo -n "$new_file_name" | xclip
	info 'Copied path to clipboard.'
}

exit 0
