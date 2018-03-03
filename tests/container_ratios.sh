#! /usr/bin/env bash

set -feE
. "$(dirname "$0")/../bhlls.sh"

 # As in nadeshiko.sh, the units are
#  bit rates: kbps
#       size: MiB
#   duration: human readable


# $1 – video
# $2 – group (General, Video, Audio)
# $3 – how the key starts
get_mediainfo_attribute() {
	local video="$1" group="$2" key="$3"
	case "$group" in
		g) group=General;;
		v) group=Video;;
		a) group=Audio;;
	esac
	mediainfo "$video" \
    	| sed -nr "/^$group$/,/^$/ {
    	                             s/^$key[^:]+:(.+)$/\1/
	                                 T
	                                 s/\s+//gp
	                               }"
}

# $1 – video
# $2 – stream type (v, a, s)
# $3 – key name
get_ffmpeg_attribute() {
	local video="$1" stype="$2" key="$3"
	ffprobe -hide_banner -v error -select_streams $stype:0 \
	        -show_entries stream=$key \
	        -of default=noprint_wrappers=1:nokey=1 \
	        "$video"
}

# $1 – video
# $2 – one_second_of_playback_size
# Returns: "container_to_ovsize_ratio<newline>container_to_1sec_ratio"
get_header_ratios() {
	local video="$1" one_second_of_playback_size="$2" \
	      header data footer containers_own_weight overall_size \
	      container_to_ovsize_ratio container_to_1sec_ratio
	read -d '' header data footer \
		< <(mediainfo -f "$video" \
	    	|& sed -rn 's/^(Header|Data|Footer)Size\s+:\s+([0-9]+).*/\2/p'; \
	        echo -en '\0' )
	[[ "$header" =~ ^[0-9]+$ ]]
	# Footer should be of zero size for Nadeshiko’s vids,
	# as we move MOOV atom to the header.
	[[ "$footer" =~ ^[0-9]+$ ]]
	[[ "$data" =~ ^[0-9]+$ ]]
	containers_own_weight=$((header+footer))
	overall_size=$((header+footer+data))
	container_to_ovsize_ratio="$(echo "scale=2; $containers_own_weight * 100 / $overall_size" | bc)" # percents
	container_to_1sec_ratio="$(echo "scale=2; $containers_own_weight*8 / $one_second_of_playback_size" | bc )"
	echo -e "$container_to_ovsize_ratio\n$container_to_1sec_ratio"
	return 0
}

# $1 – file name
gather_file_info() {
	local file="$1" i="$2" varname val
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
	duration_h=$((duration_total_s/3600))
	duration_m=$(( (duration_total_s - duration_h*3600) /60))
	duration_s=$(( (duration_total_s - duration_h*3600 - duration_m*60) ))
	[ $duration_h -ne 0 ] \
		&& duration+="${duration_h}h "
	[ $duration_m -ne 0 ] \
		&& duration+="${duration_m}m "
	duration+="${duration_s}s"

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
	elif [ "$vbitrate" != "${vbitrate%Mb/s}" ]; then
		vbitrate=${vbitrate%Mb/s}
		vbitrate=${vbitrate%.*}
		vbitrate=$((vbitrate*1000))
	else
		echo -e "Error: $file\nmediainfo reported vbitrate neither in kb/s nor Mb/s!"
		return 3
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
	if [ "$abitrate" = "${abitrate%kb/s}" ]; then
		echo -e "Error: $file\nmediainfo reported abitrate not in kb/s!"
		return 3
	else
		abitrate=${abitrate%kb/s}
		abitrate=${abitrate%.*}
	fi

	# Fun
	one_second_of_playback_size=$(( (vbitrate+abitrate)*1000 ))
	read -d '' container_to_ovsize_ratio \
	           container_to_1sec_ratio \
	    < <(get_header_ratios "$file" "$one_second_of_playback_size"; \
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
	# video
	declare -g file${i}_width=$width
	declare -g file${i}_height=$height
	declare -g file${i}_ar_16x9=$ar_16x9
	declare -g file${i}_colourspace="$colourspace"
	declare -g file${i}_chroma="$chroma"
	declare -g file${i}_chroma_yuv420="$chroma_yuv420"
	declare -g file${i}_vbitrate="$vbitrate"
	declare -g file${i}_bit_depth="$bit_depth"
	declare -g file${i}_vcodec="$vcodec"
	declare -g file${i}_vcodec_profile="$vcodec_profile"
	declare -g file${i}_writing_app="$writing_app"
	# audio
	declare -g file${i}_acodec="$acodec"
	declare -g file${i}_acodec_profile="$acodec_profile"
	declare -g file${i}_abitrate="$abitrate"

	for varname in ${!file*}; do
		[[ "$varname" =~ ^file${i}_ ]] && {
			declare -n val=$varname
			echo "${varname#file${i}_} = $val" >> container_ratios_data/$i
		}
	done
	return 0
}

# declare -g counter

# $1 – array name
print_minmax() {
	declare -n arr="$1"
	local minidx maxidx minval maxval i range_char
	for ((i=0; i<${#arr[@]}; i++)); do
		echo -n 'X'
	done
	for ((i=0; i<total_files-${#arr[@]}; i++)); do
		echo -n ' '
	done
	echo -n "|  $(echo "${#arr[@]}*100/$total_files" | bc)%"
	echo -n '  '

	# Finding minidx and maxidx values within the group.
	read -d '' minidx maxidx < <(find_min_max "$1" size_B; echo -e '\0')
	declare -n minval=file${minidx}_size_MiB
	echo -en "size: ${__b}${minval%\.*}"
	[ "$maxidx" ] && {
		declare -n maxval=file${maxidx}_size_MiB
		[ "$minval" = "$maxval" ] && range_char='~' || range_char='…'
		echo -en " $range_char $maxval"
	}
	echo -en " MiB${__s}"
	echo -n ';  '
	unset minidx maxidx
	unset -n minval maxval

# [ $((++counter)) -eq 1 ] && set -x
	read -d '' minidx maxidx < <(find_min_max "$1" duration_ms; echo -e '\0')
	declare -n minval=file${minidx}_duration
	echo -en "duration: ${__b}${minval}"
	[ "$maxidx" ] && {
		declare -n maxval=file${maxidx}_duration
		[ "$minval" = "$maxval" ] && range_char='~' || range_char='…'
		echo -en " $range_char ${maxval}"
	}
	echo -en "${__s}"
	echo -n ';  '
	unset minidx maxidx
	unset -n minval maxval
# [ $counter -eq 1 ] && set +x && exit

	read -d '' minidx maxidx < <(find_min_max "$1" vbitrate; echo -e '\0')
	declare -n minval=file${minidx}_vbitrate
	echo -en "vbitrate: ${__b}${minval}"
	[ "$maxidx" ] && {
		declare -n maxval=file${maxidx}_vbitrate
		[ "$minval" = "$maxval" ] && range_char='~' || range_char='…'
		echo -en " $range_char ${maxval}"
	}
	echo -en " kbps${__s}"
	echo -n ';  '

	find_peculiarities "$1"
	echo
	return 0
}

# $1 – array name
# $2 – type of data to compare
# Returns a string with two array indexes: "minimum<space>maximum".
#   or with one array index, if min == max.
find_min_max() {
	declare -n arr="$1"
	local data_type="$2" minval maxval minidx maxidx i val
	for i in ${!arr[@]}; do
		declare -n val=file${i}_$data_type
		[ -v minidx ] || { minidx=$i maxidx=$i minval=$val maxval=$val; }
		[ -v val -a -v minval ] && [ "$val" -lt "$minval" ] \
			&& minidx=$i minval="$val"
		[ -v val -a -v maxval ] && [ "$val" -gt "$maxval" ] \
			&& maxidx=$i maxval="$val"
	done
	if [ -v minidx -a -v maxidx ] && [ "$minidx" = "$maxidx" ]; then
		echo $minidx
	else
		echo $minidx $maxidx
	fi
	return 0
}

find_peculiarities() {
	declare -n arr="$1"
	local val idx unusual_ar=() unusual_chroma=() unusual_bit_depth=() \
	      unusual_vcodec_profile=()

	for idx in ${!arr[@]}; do
		declare -n val=file${idx}_ar_16x9
		[ "$val" = no ] && unusual_ar+=( [$idx]="$val" )
		declare -n val=file${idx}_chroma_yuv420
		[ "$val" = no ] && unusual_chroma+=( [$idx]="$val" )
		declare -n val=file${idx}_bit_depth
		[ "$val" != 8 ] && unusual_bit_depth+=( [$idx]="$val")
		declare -n val=file${idx}_vcodec_profile
		[[ "$val" =~ ^(Baseline|Main|High)\@L[0-9]\.?[0-9]?$ ]] \
			|| unusual_vcodec_profile+=( [$idx]="$val" )
	done
	[ ${#unusual_ar[@]} -ne 0 ] \
		&& echo -en " ${__r}not_a_16x9${__s}" \
		&& echo -en "${__b}(${!unusual_ar[@]})${__s}"

	[ ${#unusual_chroma[@]} -ne 0 ] \
		&& echo -en " ${__r}not_yuv420${__s}" \
		&& echo -en "${__b}(${!unusual_chroma[@]})${__s}"

	[ ${#unusual_bit_depth[@]} -ne 0 ] \
		&& echo -en " ${__r}not_8bit${__s}" \
		&& echo -en "${__b}(${!unusual_chroma[@]})${__s}"

	[ ${#unusual_vcodec_profile[@]} -ne 0 ] \
		&& echo -en " ${__r}vc_profile${__s}" \
		&& echo -en "${__b}(${!unusual_chroma[@]})${__s}"
	return 0
}

# $1 – array name
print_ids() {
	declare -n arr="$1"
	local i val
	for i in ${!arr[@]}; do
		echo -en " ${__b}$i${__s}"
	done
	echo
	return 0
}

# $1 – array name
print_values() {
	declare -n arr="$1"
	local i val
	for i in ${!arr[@]}; do
		echo -en " ${__b}${arr[i]}${__s}"
	done
	echo
	return 0
}

rm -rf "$MYDIR/container_ratios_data"
mkdir container_ratios_data
i=-1
while IFS= read -r -d '' ; do
	gather_file_info "$REPLY" $((++i)) || exit $?
done  < <(find -iname "*.mp4" -printf "%P\0")
total_files=$i

for varname in ${!file*}; do
	declare -n val=$varname
	[[ "$varname" =~ file([0-9]+)_container_to_ovsize_ratio$ ]] && {
		idx=${BASH_REMATCH[1]}
		if [ "$(echo "$val <= 0.1" | bc)" = 1 ]; then
			container_to_ovsize_le_01+=( [$idx]="$val")
		elif [ "$(echo "$val <= 0.2" | bc)" = 1 ]; then
			container_to_ovsize_le_02+=( [$idx]="$val")
		elif [ "$(echo "$val <= 0.3" | bc)" = 1 ]; then
			container_to_ovsize_le_03+=( [$idx]="$val")
		elif [ "$(echo "$val <= 0.4" | bc)" = 1 ]; then
			container_to_ovsize_le_04+=( [$idx]="$val")
		elif [ "$(echo "$val <= 0.5" | bc)" = 1 ]; then
			container_to_ovsize_le_05+=( [$idx]="$val")
		elif [ "$(echo "$val <= 1" | bc)" = 1 ]; then
			container_to_ovsize_le_1+=( [$idx]="$val")
		elif [ "$(echo "$val <= 2" | bc)" = 1 ]; then
			container_to_ovsize_le_2+=( [$idx]="$val")
		elif [ "$(echo "$val <= 5" | bc)" = 1 ]; then
			container_to_ovsize_le_5+=( [$idx]="$val")
		else
			container_to_ovsize_others+=( [$idx]="$val")
		fi
	}
	[[ "$varname" =~ file([0-9]+)_container_to_1sec_ratio$ ]] && {
		idx=${BASH_REMATCH[1]}
		if [ "$(echo "$val <= 0.5" | bc)" = 1 ]; then
			container_to_1sec_le_05+=( [$idx]="$val")
		elif [ "$(echo "$val <= 1" | bc)" = 1 ]; then
			container_to_1sec_le_1+=( [$idx]="$val")
		elif [ "$(echo "$val <= 2" | bc)" = 1 ]; then
			container_to_1sec_le_2+=( [$idx]="$val")
		elif [ "$(echo "$val <= 3" | bc)" = 1 ]; then
			container_to_1sec_le_3+=( [$idx]="$val")
		elif [ "$(echo "$val <= 4" | bc)" = 1 ]; then
			container_to_1sec_le_4+=( [$idx]="$val")
		elif [ "$(echo "$val <= 5" | bc)" = 1 ]; then
			container_to_1sec_le_5+=( [$idx]="$val")
		elif [ "$(echo "$val <= 10" | bc)" = 1 ]; then
			container_to_1sec_le_10+=( [$idx]="$val")
		elif [ "$(echo "$val <= 20" | bc)" = 1 ]; then
			container_to_1sec_le_20+=( [$idx]="$val")
		elif [ "$(echo "$val <= 30" | bc)" = 1 ]; then
			container_to_1sec_le_30+=( [$idx]="$val")
		else
			container_to_1sec_others+=( [$idx]="$val")
		fi
	}
done

modes=( 'minmax' 'values' 'ids' )
mode_idx=0
until [ -v quit ]; do
	echo -e "\n\n    Mode: ${__b}${modes[mode_idx]^^}${__s} \n"
	echo "Header+footer to file size ratio:"
	[ ${#container_to_ovsize_le_01[@]} -ne 0 ] \
	&& { echo -n '<= 0.1% | '; print_${modes[mode_idx]} container_to_ovsize_le_01; }
	[ ${#container_to_ovsize_le_02[@]} -ne 0 ] \
	&& { echo -n '<= 0.2% | '; print_${modes[mode_idx]} container_to_ovsize_le_02; }
	[ ${#container_to_ovsize_le_03[@]} -ne 0 ] \
	&& { echo -n '<= 0.3% | '; print_${modes[mode_idx]} container_to_ovsize_le_03; }
	[ ${#container_to_ovsize_le_04[@]} -ne 0 ] \
	&& { echo -n '<= 0.4% | '; print_${modes[mode_idx]} container_to_ovsize_le_04; }
	[ ${#container_to_ovsize_le_05[@]} -ne 0 ] \
	&& { echo -n '<= 0.5% | '; print_${modes[mode_idx]} container_to_ovsize_le_05; }
	[ ${#container_to_ovsize_le_1[@]} -ne 0 ] \
	&& { echo -n '  <= 1% | '; print_${modes[mode_idx]} container_to_ovsize_le_1; }
	[ ${#container_to_ovsize_le_2[@]} -ne 0 ] \
	&& { echo -n '  <= 2% | '; print_${modes[mode_idx]} container_to_ovsize_le_2; }
	[ ${#container_to_ovsize_le_5[@]} -ne 0 ] \
	&& { echo -n '  <= 5% | '; print_${modes[mode_idx]} container_to_ovsize_le_5; }
	[ ${#container_to_ovsize_others[@]} -ne 0 ] \
	&& { echo -n ' others | '; print_${modes[mode_idx]} container_to_ovsize_others; }
	[ "${modes[mode_idx]}" = minmax ] && {
		echo 'Peculiarities in unusual: AR: aspect ratio is not 16:9'
	}
	echo

	echo "Header+footer to one second worth of playback:"
	[ ${#container_to_1sec_le_05[@]} -ne 0 ] \
	&& { echo -n ' <= .5s | '; print_${modes[mode_idx]} container_to_1sec_le_05; }
	[ ${#container_to_1sec_le_1[@]} -ne 0 ] \
	&& { echo -n '  <= 1s | '; print_${modes[mode_idx]} container_to_1sec_le_1; }
	[ ${#container_to_1sec_le_2[@]} -ne 0 ] \
	&& { echo -n '  <= 2s | '; print_${modes[mode_idx]} container_to_1sec_le_2; }
	[ ${#container_to_1sec_le_3[@]} -ne 0 ] \
	&& { echo -n '  <= 3s | '; print_${modes[mode_idx]} container_to_1sec_le_3; }
	[ ${#container_to_1sec_le_4[@]} -ne 0 ] \
	&& { echo -n '  <= 4s | '; print_${modes[mode_idx]} container_to_1sec_le_4; }
	[ ${#container_to_1sec_le_5[@]} -ne 0 ] \
	&& { echo -n '  <= 5s | '; print_${modes[mode_idx]} container_to_1sec_le_5; }
	[ ${#container_to_1sec_le_10[@]} -ne 0 ] \
	&& { echo -n ' <= 10s | '; print_${modes[mode_idx]} container_to_1sec_le_10; }
	[ ${#container_to_1sec_le_20[@]} -ne 0 ] \
	&& { echo -n ' <= 20s | '; print_${modes[mode_idx]} container_to_1sec_le_20; }
	[ ${#container_to_1sec_le_30[@]} -ne 0 ] \
	&& { echo -n ' <= 30s | '; print_${modes[mode_idx]} container_to_1sec_le_30; }
	[ ${#container_to_1sec_others[@]} -ne 0 ] \
	&& { echo -n ' others | '; print_${modes[mode_idx]} container_to_1sec_others; }

	[ $((++mode_idx)) -eq ${#modes[@]} ] && mode_idx=0

	echo -e "\n${__g}<${__s}Space${__g}>${__s} to switch mode, ${__g}<${__s}Q${__g}>${__s} to quit."
	false
	read -n1 -s
	[[ "$REPLY" = @(q|Q) ]] && quit=t && echo
done

exit 0
