#  $1 – video
#  $2 – one_second_of_playback_size
#  Returns: "container_to_ovsize_ratio<newline>container_to_1sec_ratio"
get_header_ratios() {
	local video="$1" one_second_of_playback_size="$2" \
	      header data footer containers_own_weight overall_size \
	      container_to_ovsize_ratio container_to_1sec_ratio
	read -d '' header data footer \
		< <(mediainfo -f "$video" \
	    	|& sed -rn 's/^(Header|Data|Footer)Size\s+:\s+([0-9]+).*/\2/p'; \
	        echo -en '\0' )
	[[ "$header" =~ ^[0-9]+$ ]]  \
		|| err "Couldn’t determine header length."
	# Footer should be of zero size for Nadeshiko’s vids,
	# as we move MOOV atom to the header.
	[[ "$footer" =~ ^[0-9]+$ ]]  \
		|| err "Couldn’t determine footer length."
	[[ "$data" =~ ^[0-9]+$ ]]  \
		|| err "Couldn’t determine data length."
	containers_own_weight=$((header+footer))
	overall_size=$((header+footer+data))
	container_to_ovsize_ratio="$(echo "scale=2; $containers_own_weight * 100 / $overall_size" | bc)" # percents
	container_to_1sec_ratio="$(echo "scale=2; $containers_own_weight*8 / $one_second_of_playback_size" | bc )"
	echo -e "$container_to_ovsize_ratio\n$container_to_1sec_ratio"
	return 0
}


 # Takes total number of seconds, returns “Nh NNm NNs”,
#  if hours or minutes are unset they are omitted.
#  $1 – total number of seconds.
#
get_duration_pretty() {
	local total_s="$1" h m s duration
	total_s=${total_s%.*}  # strip milliseconds
	h=$(( total_s/3600  ))
	m=$(( (total_s - h*3600) /60))
	s=$(( (total_s - h*3600 - m*60) ))
	[ $h -ne 0 ] \
		&& duration+="${h}h "
	[ $m -ne 0 ] \
		&& duration+="${m}m "
	duration+="${s}s"
	echo "$duration"
	return 0
}


#  $1 – file name
#  $2 – index
gather_file_info() {
	local file="$1" i="$2"
	local fsize_B fsize_real_MiB fsize_MiB within_2M within_10M within_20M \
	      duration duration_ms duration_total_s \
	      duration_h duration_m duration_s \
	      width height ar_16x9 \
	      colourspace chroma \
	      vcodec vbitrate vcodec_profile bit_depth \
	      acodec abitrate acodec_profile \
	      one_second_of_playback_size \
	      container_to_ovsize_ratio container_to_1sec_ratio \
	      writing_app
	# general
	fsize_B="$(stat --printf %s "$file")"
	fsize_real_MiB="$(echo "scale=10; $fsize_B/1024/1024" | bc)"
	fsize_MiB="${fsize_real_MiB%.*}"
	[ $fsize_B -le $((2*1024*1024)) ] \
		&& within_2M=yes \
		|| within_2M=no
	[ $fsize_B -le $((10*1024*1024)) ] \
		&& within_10M=yes \
		|| within_10M=no
	[ $fsize_B -le $((20*1024*1024)) ] \
		&& within_20M=yes \
		|| within_20M=no

	 # Duration in human-readable format from mediainfo
	#  cannot be relied upon. Hence our own.
	#
	# duration=$(get_mediainfo_attribute "$file" g Duration)
	duration_s="$(get_ffmpeg_attribute "$file" v duration)"
	duration_s="${duration_s%???}"
	duration_ms="${duration_s/./}"
	duration_total_s=$(( duration_ms /1000))
	duration=$(get_duration_pretty $duration_total_s)

	# video
	width=$(get_ffmpeg_attribute "$file" v width)
	height=$(get_ffmpeg_attribute "$file" v height)
	ar_16x9=$(echo "scale=7; $width/$height == 16/9" | bc )
	case "$ar_16x9" in
		0) ar_16x9=no;;
		1) ar_16x9=yes;;
		*) ar_16x9=undefined;;
	esac
	colourspace=$(get_mediainfo_attribute "$file" v "Color space")
	chroma=$(get_mediainfo_attribute "$file" v Chroma)
	[ "$chroma" = '4:2:0' -a "$colourspace" = YUV ] \
		&& chroma_yuv420=yes \
		|| chroma_yuv420=no
	vbitrate=$(get_mediainfo_attribute "$file" v "Bit rate")
	if [ "$vbitrate" != "${vbitrate%kb/s}" ]; then
		vbitrate=${vbitrate%kb/s}
		vbitrate=${vbitrate%.*}
		vbitrate_trustworthy=yes
	elif [ "$vbitrate" != "${vbitrate%Mb/s}" ]; then
		vbitrate=${vbitrate%Mb/s}
		vbitrate=${vbitrate%.*}
		vbitrate=$((vbitrate*1000))
		vbitrate_trustworthy=yes
	else
		vbitrate=0
		vbitrate_trustworthy=no
		# [ -z "$vbitrate" ] && {
		# 	vbitrate=$(get_mediainfo_attribute "$file" v "FromStats_BitRate")
		# 	vbitrate=$((vbitrate/1000))
		# }
	fi
	bit_depth=$(get_mediainfo_attribute "$file" v "Bit depth")
	bit_depth=${bit_depth%bits}
	vcodec=$(get_mediainfo_attribute "$file" v "Format  ")
	vcodec_profile=$(get_mediainfo_attribute "$file" v "Format profile")
	writing_app=$(get_mediainfo_attribute "$file" g "Writing application")

	# audio
	acodec=$(get_mediainfo_attribute "$file" a "Format  ")
	acodec_profile=$(get_mediainfo_attribute "$file" a "Format profile")
	abitrate=$(get_mediainfo_attribute "$file" a "Bit rate  ")
	if [ "$abitrate" != "${abitrate%kb/s}" ]; then
		abitrate=${abitrate%kb/s}
		abitrate=${abitrate%.*}
		abitrate_trustworthy=yes
	else
		if [ -z "$abitrate" ]; then
		# 	abitrate=$(get_mediainfo_attribute "$file" a "FromStats_BitRate")
		# 	abitrate=$((abitrate/1000))
		# else
			# No audio track, possibly
			abitrate=0
		fi
		abitrate_trustworthy=no
	fi
	overall_bitrate=$(get_mediainfo_attribute "$file" g "Overall bit rate")

	# Fun
	one_second_of_playback_size=$(( (vbitrate+abitrate)*1000 ))
	read -d '' container_to_ovsize_ratio \
	           container_to_1sec_ratio \
	    < <(get_header_ratios "$file" "$one_second_of_playback_size" || :; \
	        echo -e '\0')

	declare -g file${i}_name="\"$file\""
	declare -g file${i}_size_B="$fsize_B"
	declare -g file${i}_size_real_MiB="$fsize_real_MiB"
	declare -g file${i}_size_MiB="$fsize_MiB"
	declare -g file${i}_within_2M=$within_2M
	declare -g file${i}_within_10M=$within_10M
	declare -g file${i}_within_20M=$within_20M
	declare -g file${i}_duration="$duration"
	declare -g file${i}_duration_total_s="$duration_total_s"
	declare -g file${i}_duration_ms="$duration_ms"
	declare -g file${i}_container_to_ovsize_ratio="$container_to_ovsize_ratio"
	declare -g file${i}_container_to_1sec_ratio="$container_to_1sec_ratio"
	declare -g file${i}_overall_bitrate="$overall_bitrate"
	# video
	declare -g file${i}_width=$width
	declare -g file${i}_height=$height
	declare -g file${i}_ar_16x9=$ar_16x9
	declare -g file${i}_colourspace="$colourspace"
	declare -g file${i}_chroma="$chroma"
	declare -g file${i}_chroma_yuv420="$chroma_yuv420"
	declare -g file${i}_vbitrate="$vbitrate"
	declare -g file${i}_vbitrate_trustworthy="$vbitrate_trustworthy"
	declare -g file${i}_bit_depth="$bit_depth"
	declare -g file${i}_vcodec="$vcodec"
	declare -g file${i}_vcodec_profile="$vcodec_profile"
	declare -g file${i}_writing_app="$writing_app"
	# audio
	declare -g file${i}_acodec="$acodec"
	declare -g file${i}_acodec_profile="$acodec_profile"
	declare -g file${i}_abitrate="$abitrate"
	declare -g file${i}_abitrate_trustworthy="$abitrate_trustworthy"

	return 0
}


#  $1 – file name
comme_il_faut_check() {
	local new_file_name="$1" profile_name profile_level height_ok mbw
	info "Running validity and compatibility checks."
	gather_file_info "$new_file_name" 1
	if [ -v scale ]; then
		[ "$file1_height" = "$scale" ] \
			|| warn "Height is “$file1_height”. Should be $scale."
	elif [ -v crop ]; then
		[ "$file1_height" = "$crop_h" ] \
			|| warn "Height is “$file1_height”. Should be $crop_h."
	else
		[ "$file1_height" = "$orig_height" ] \
			||  warn "Height is “$file1_height”. Should be $orig_height."
	fi
	[ "$file1_chroma_yuv420" = no ] \
		&& warn "Chroma subsampling is “$file1_colourspace $file1_chroma”. Should be YUV 4:2:0."
	unset mbw
	[ "$file1_vbitrate" != "$((vbitrate_bits/1000))" ] && {
		[ "$file1_vbitrate_trustworthy" = no ] && mbw=' (may be wrong)'
		warn "Video bitrate is “$file1_vbitrate” kbps$mbw.
		      Should be $((vbitrate_bits/1000)) kbps."
	}
	[ "$file1_bit_depth" != '8' ] \
		&& warn "Bit depth is “$file1_bit_depth”. Should be 8 bits."
	[[ "$file1_vcodec" =~ ^(AVC|VP9)$ ]] \
		|| warn "Video codec is “$file1_bit_depth”. Recommended are AVC or VP9."
	[ "$file1_vcodec" = AVC ] && {
		if [[ "$file1_vcodec_profile" =~ ^(.*)\@L(([0-9])\.?[0-9]?)$ ]]; then
			profile_name=${BASH_REMATCH[1]}
			profile_level=${BASH_REMATCH[2]}
			profile_level_1=${BASH_REMATCH[3]}
			[ "${profile_name,,}" != "$libx264_profile" ] \
				&& warn "Video codec profile is “${profile_name,,}”. Should be “$libx264_profile”."
			[ "$profile_level" != "$libx264_level" ] \
				&& warn "Video codec profile level is “$profile_level”. Should be $libx264_level."
			[[ "$profile_name" =~ ^([Bb]ase[Ll]ine|[Mm]ain|[Hh]igh)$ ]] \
				|| warn "Profile “$profile_name” is not widely supported."
			[[ "$profile_level_1" =~ ^(1|2|3|4|5)$ ]] \
				|| warn "Profile level “$profile_level” is not widely supported."
		else
			warn "Unknown H264 profile: “$file1_vcodec_profile”."
		fi
	}
	unset mbw
	[ "$((file1_abitrate*1000))" != "${abitrate_bits:-0}" ] && {
		[ "$file1_abitrate_trustworthy" = no ] && mbw=' (may be wrong)'
		warn "Audio bitrate is “$file1_abitrate” kbps$mbw.
		      Should be $((${abitrate_bits:-0}/1000)) kbps."
	}
	if [    "$file1_vbitrate_trustworthy" = no  \
	     -o "$file1_abitrate_trustworthy" = no ]
	then
		info "Overall bitrate: $file1_overall_bitrate."
	fi
	return 0
}
