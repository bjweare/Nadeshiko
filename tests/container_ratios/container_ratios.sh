#! /usr/bin/env bash

set -feE
VERBOSITY_LEVEL=330

. "$(dirname "$0")/../../lib/bahelite/bahelite.sh"
. "$(dirname "$0")/../../lib/gather_file_info.sh"

webm_dir="${1:-}"
[ -d "$webm_dir" ] || {
	echo "Pass a directory with webms to this script" >&2
	exit 3
}

values_full_report=/tmp/values_report.csv
echo 'Overhead, in ESP; Frame count; Duration, s; Combined bitrate, k;'  \
	> "$values_full_report"

start_logging

 # As in nadeshiko.sh, the units are
#  bit rates: kbps
#       size: MiB
#   duration: human readable


# declare -g counter

# $1 – array name
print_minmax() {
	declare -n arr="$1"
	local minidx maxidx _minval _maxval minval maxval i range_char  \
	      Xs_line_length=15

	arr_pct_of_total_files_pretty=$(echo "${#arr[@]}*100/$total_files" | bc)
	arr_pct_of_total_files=${arr_pct_of_total_files_pretty%\.*}

	arr_pct_as_Xs=$(( arr_pct_of_total_files * Xs_line_length / 100 ))

	for ((i=0; i<arr_pct_as_Xs; i++)); do
		echo -n 'X'
	done
	for ((i=0; i<Xs_line_length - arr_pct_as_Xs; i++)); do
		echo -n ' '
	done
	echo -n " | $(printf "%${#total_files}d" ${#arr[*]}) files"
	echo -n " or $(printf "%3d" $arr_pct_of_total_files_pretty) %"
	echo -n ';  '

	# Finding minidx and maxidx values within the group.
	read -d '' minidx maxidx < <(find_min_max "$1" '' fsize_B; echo -e '\0')
	declare -n _minval=file${minidx}[fsize_MiB]
	minval=${_minval%\.*}
	echo -en "size: ${__bri}$minval"
	[ "$maxidx" ] && {
		declare -n _maxval=file${maxidx}[fsize_MiB]
		maxval=${_maxval%\.*}
		[ "$minval" = "$maxval" ] && range_char='~' || range_char='…'
		echo -en " $range_char $maxval"
	}
	echo -en " MiB${__s}"
	echo -n ';  '
	unset minidx maxidx
	unset -n minval maxval

# [ $((++counter)) -eq 1 ] && set -x
	read -d '' minidx maxidx < <(find_min_max "$1" '_v' duration_total_s_ms; echo -e '\0')
	declare -n _minval=file${minidx}_v[duration_total_s_ms]
	minval=${_minval%\.*}
	echo -en "duration: ${__bri}${minval}"
	[ "$maxidx" ] && {
		declare -n _maxval=file${maxidx}_v[duration_total_s_ms]
		maxval=${_maxval%\.*}
		[ "$minval" = "$maxval" ] && range_char='~' || range_char='…'
		echo -en " $range_char ${maxval}"
	}
	echo -en " s${__s}"
	echo -n ';  '
	unset minidx maxidx
	unset -n minval maxval
# [ $counter -eq 1 ] && set +x && exit

	read -d '' minidx maxidx < <(find_min_max "$1" '_c' bitrate_by_extraction; echo -e '\0')
	declare -n _minval=file${minidx}_c[bitrate_by_extraction]
	minval=${_minval%\.*}
	echo -en "cbitrate: ${__bri}$(pretty "$minval")"
	[ "$maxidx" ] && {
		declare -n _maxval=file${maxidx}_c[bitrate_by_extraction]
		maxval=${_maxval%\.*}
		[ "$minval" = "$maxval" ] && range_char='~' || range_char='…'
		echo -en " $range_char $(pretty "$maxval")"
	}
	echo -en "${__s}"
	echo -n ';  '

	read -d '' minidx maxidx < <(find_min_max "$1" '_v' frame-heaviness; echo -e '\0')
	declare -n _minval=file${minidx}_v[frame-heaviness]
	minval=${_minval%\.*}
	echo -en "frame-heaviness: ${__bri}$(pretty "$minval")"
	[ "$maxidx" ] && {
		declare -n _maxval=file${maxidx}_v[frame-heaviness]
		maxval=${_maxval%\.*}
		[ "$minval" = "$maxval" ] && range_char='~' || range_char='…'
		echo -en " $range_char $(pretty "$maxval")"
	}
	echo -en "${__s}"
	echo -n ';  '


	read -d '' minidx maxidx < <(find_min_max "$1" '_v' frame_count; echo -e '\0')
	declare -n _minval=file${minidx}_v[frame_count]
	minval=${_minval%\.*}
	echo -en "frame_count: ${__bri}$(pretty "$minval")"
	[ "$maxidx" ] && {
		declare -n _maxval=file${maxidx}_v[frame_count]
		maxval=${_maxval%\.*}
		[ "$minval" = "$maxval" ] && range_char='~' || range_char='…'
		echo -en " $range_char $(pretty "$maxval")"
	}
	echo -en "${__s}"
	echo -n ';  '


	read -d '' arith_mean < <(find_arith_mean "$1" '_v' frame_count; echo -e '\0')
	echo -en "frame_count ar. mean: ${__bri}$(pretty "$arith_mean")${__s}"
	echo -n ''

	# find_peculiarities "$1"
	echo
	return 0
}


# $1 – array name
# $2 – type of data to compare
# Returns a string with two array indexes: "minimum<space>maximum".
#   or with one array index, if min == max.
find_min_max() {
	declare -n arr="$1"
	local suffix="${2:-}"  data_type="$3" minval maxval minidx maxidx i val
	minval=999999999999
	maxval=-999999999999
	for i in ${!arr[@]}; do
		declare -n val="file${i}${suffix:-}[$data_type]"
		cval=${val%\.*}
		(( cval > maxval )) && maxval=$cval maxidx=$i
		(( cval < minval )) && minval=$cval minidx=$i

		# [ -v minidx ] || { minidx=$i maxidx=$i minval=$val maxval=$val; }
		# [ -v val -a -v minval ] && [ "${val%.*}" -lt "${minval%.*}" ] \
		# 	&& minidx=$i minval="$val"
		# [ -v val -a -v maxval ] && [ "${val%.*}" -gt "${maxval%.*}" ] \
		# 	&& maxidx=$i maxval="$val"
	done
	if (( maxval == minval )); then
		echo $minidx
	else
		echo $minidx $maxidx
	fi
	return 0
}


# $1 – array name
# $2 – type of data to compare
# Returns a string with two array indexes: "minimum<space>maximum".
#   or with one array index, if min == max.
find_arith_mean() {
	declare -n arr="$1"
	local suffix="${2:-}"  data_type="$3" i val  vals  arith_mean
	for i in ${!arr[@]}; do
		declare -n val="file${i}${suffix:-}[$data_type]"
		vals+=($val)
	done
	arith_mean=$(
		echo "scale=4; am = (  $(IFS='+'; echo "${vals[*]}")  )  / ${#vals[*]};  \
		      scale=0; am/1" | bc
	)
	echo "$arith_mean"
	return 0
}

find_peculiarities() {
	declare -n arr="$1"
	local val idx unusual_ar=() unusual_chroma=() unusual_bit_depth=() \
	      unusual_vcodec_profile=()

	for idx in ${!arr[@]}; do
		[ -v file${idx}_v[is_16to9] ]  \
			|| unusual_ar+=( [$idx]="$idx" )  # should be ar
		# declare -n val=file${idx}_chroma_yuv420
		# [ "$val" = no ] && unusual_chroma+=( [$idx]="$val" )
		# declare -n val=file${idx}_bit_depth
		# [ "$val" != 8 ] && unusual_bit_depth+=( [$idx]="$val")
		# declare -n val=file${idx}_vcodec_profile
		# [[ "$val" =~ ^(Baseline|Main|High)\@L[0-9]\.?[0-9]?$ ]] \
		# 	|| unusual_vcodec_profile+=( [$idx]="$val" )
	done
	[ ${#unusual_ar[@]} -ne 0 ] \
		&& echo -en " ${__r}not_a_16x9${__s}" \
		&& echo -en "${__bri}(${!unusual_ar[@]})${__s}"

	# [ ${#unusual_chroma[@]} -ne 0 ] \
	# 	&& echo -en " ${__r}not_yuv420${__s}" \
	# 	&& echo -en "${__bri}(${!unusual_chroma[@]})${__s}"

	# [ ${#unusual_bit_depth[@]} -ne 0 ] \
	# 	&& echo -en " ${__r}not_8bit${__s}" \
	# 	&& echo -en "${__bri}(${!unusual_bit_depth[@]})${__s}"

	# [ ${#unusual_vcodec_profile[@]} -ne 0 ] \
	# 	&& echo -en " ${__r}vc_profile${__s}" \
	# 	&& echo -en "${__bri}(${!unusual_vcodec_profile[@]})${__s}"
	return 0
}

# $1 – array name
print_ids() {
	declare -n arr="$1"
	local i val
	for i in ${!arr[@]}; do
		echo -en " $(id "$i")"
	done
	echo
	return 0
}

# $1 – array name
print_ids_with_tags() {
	declare -n arr="$1"
	local i val
	for i in ${!arr[@]}; do
		echo -en " $(id "$i" 'with_tags')"
	done
	echo
	return 0
}


print_id_legend() {
	echo -e "
	${__bri}${id_colour_regular}ID${__s} – regular file.
	${__bri}${id_colour_resolution}ID${__s} – resolution is non-standard (i.e. not 16:9 – most probably just cropped, but may be 4:3 or 2.35:1).
	${__bri}${id_colour_autoscale}ID${__s} – resolution is downscaled.
	${__bri}${id_colour_bigfilesize}${__black}ID${__s} – file size > 20 MiB.
	${__bri}${id_colour_pixfmt}ID${__s} – pix_fmt is not yuv420p (better).


	"
}


# $1 – array name
print_values() {
	declare -n arr="$1"
	[[ "$1" =~ ^ratio_to_1sec ]] && {
		gather_report=t
		report="$values_full_report"
	}
	local i val
	for i in ${!arr[@]}; do
		echo -en " ${__bri}${arr[i]}${__s}"
		[ -v gather_report ] && {
			local -n __file_v=file${i}_v
			local -n __file_c=file${i}_c
			echo -n "${arr[i]};"  >>"$report"
			echo -n "${__file_v[frame_count]};"  >>"$report"
			echo -n "${__file_v[duration_total_s_ms]%\.*};"  >>"$report"
			echo -n "$(( __file_c[bitrate_by_extraction]/1000))"  >>"$report"
			echo >> "$report"
		}
	done
	echo
	return 0
}

#  $1 – some number to shorten into 999k
pretty() {
	local var="$1" allow_M_unit=${2:-}
	 # Setting _pretty variable for display
	#
	#  M’s cut too much, seeing 2430k would be more informative, than “2M”.
	#  “Is that 2000k or 2900k?” Those 900k make a difference.
	#
	#                                  23’123’123
	if [[ -v allow_M_unit  && "$var" =~ ........$ ]]; then
		var="$((var/1000000))M"

	#                 23’123
	elif [[ "$var" =~ .....$ ]]; then
		var="$((var/1000))k"
	fi
	#  If $var bears a five-digit number, introduce a thousand separator: ’
	[[ "$var" =~ ^([0-9]{2,})([0-9]{3})(k|M)$ ]] && {
		var="${BASH_REMATCH[1]}’${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
	}
	echo "$var"
	return 0
}


 # Prints a file ID highlighted
#  $1 – a number that is a file id, 0-based.
#
id() {
	local id="$1"  with_tags  vval  vval_c  vval_v  c  extra  extra_tags
	[ "${2:-}" ] && with_tags=t
	[[ "$id" =~ ^[0-9]+$ ]]
	(( id > -1 && id < total_files ))
	declare -n vval=file$i
	declare -n vval_c=file${i}_c
	declare -n vval_v=file${i}_v

	#  Primary attributes
	#  Things that tell to filter out some files quickly.
	#  1. Enormous file size. (The file obviously wasn’t subjected to fit into
	#     a size limit and obey lower-than-desired encoding options)
	if (( vval[fsize_B] > normal_file_size_limit )); then
		c=$id_colour_bigfilesize
	fi

	#  Secondary attributes
	#  Peculiarities, that should stand out. Things that represent something
	#  important for the measuring of what affects muxing overhead.
	#  1. Autoscale.
	#     A resolution
	#     Highlighted in red, because this is the primary reason, why the
	#     encoding process approaches the file size and may exceed it.
	#     I.e. long duration → need to downscale → need to fit size in the limit.
	if [[ "${vval[path]##*/}" =~ \[AS\] ]]; then
		: ${c:=$id_colour_autoscale}
		extra+=("AS=${vval_v[height]}p")

	#  2. Non-standard resolution (most probably cropped).
	#     Cropped webms complicate the prediction of overhead, because
	#     it creates a wide variety of cases, that blur boundaries between
	#     what was encoded in one bitrate-resolution profile and another.
	#     E.g. a cropped 1080p may be alike to native 720p or 480p in the
	#     retrieved data, such as the number of pixels in a frame, but
	#     the complexity, with which cropped 1080p frames were encoded
	#     remained that of the 1080p profile, which is not like 720p or 480p.
	elif ! [[ "${vval_v[resolution]}" =~ ^($(IFS='|'; echo "${list_of_common_resolutions[*]}"))$ ]]; then
		: ${c:=$id_colour_resolution}
		extra+=(${vval_v[resolution]})

	fi

	#  Tertiary attributes
	#  That affect muxing overhead only slightly or do not at all or it is
	#  not known, if they affect it or not, but because of their nature
	#  (i.e. closeness to something basic) there is a reason to suspect, that
	#  these attributes somehow affect muxing_overhead.
	#  1. Non-standard pix_fmt (colourspace+chroma+bitness)
	#     Separate tag!
	if [ "${vval_v[pix_fmt]}" != yuv420p ]; then
		extra+=( "${vval_v[pix_fmt]}")
		: ${c:=$id_colour_pixfmt}
	fi

	[ -v with_tags  -a  ${#extra[*]} -ne 0 ]  \
		&& extra_tags=$(IFS=','; echo "[${extra[*]}]")

	echo -e "${__bri}${c:-$id_colour_regular}$id${__s}${extra_tags:-}"
	return 0
}

datadir="$(date +%F_%T)"
mkdir "$datadir"
# TMPDIR="/tmp/container_ratios"
mkdir -p "$TMPDIR/file_info"

dummy_video_title="Dummy video title 255 characters long."
until (( ${#dummy_video_title} > 255 )); do
	dummy_video_title+=" $dummy_video_title"
done
dummy_video_title=${dummy_video_title:0:255}

normal_file_size_limit=$(( 20 * 1024 * 1024 ))

for res in 360p 480p 576p 720p 1080p 1440p 2160p; do
	h=${res%p}
	w=$((h*16/9))
	list_of_common_resolutions+=( "$w×$h" )
done

id_colour_autoscale=${__red}
id_colour_resolution=${__cyan}
id_colour_bigfilesize=${__invert_bg_fg}${__black}
id_colour_pixfmt=${__magenta}
id_colour_regular=${__white}

i=0
# set -x
info "Gathering information…"
echo -n '(1 dot = 1 file)  '
while IFS= read -r -d '' ; do
	declare -A file$i
	declare -n cur_file=file$i
	# origwebm_path=
	# #  Remuxing the webm to have only the video track in the container –
	# #  as the presence of audio would spoil the data. This test is for
	# #  video track specifically, estimating the overhead caused by
	# #
	# ffmpeg -i "$origwebm_path" -c:v copy -an -sn -dn \
	#        -map_metadata -1  -map_chapters -1  \
	#        -metadata title="$dummy_video_title"  \
	#        -metadata comment="Converted with Nadeshiko vX.Y.Z"  \
	cur_file[path]="$webm_dir/$REPLY"
	gather_info 'container-ratios' "file$i" || exit $?
	# for key in ${!cur_file[@]}; do
	# 	echo "${cur_file[$key]@A}" >>"$TMPDIR/file_info/$i"
	# done
	declare -p file$i >>"$TMPDIR/file_info/$i"
	declare -p file${i}_c >>"$TMPDIR/file_info/$i"
	declare -p file${i}_v >>"$TMPDIR/file_info/$i"
	declare -p file${i}_a >>"$TMPDIR/file_info/$i"
	let '++i, 1'
	echo -n '.'  # Mark of a file
done  < <(find -L "$webm_dir" -maxdepth 1 -iname "*.webm" -printf "%P\0")
total_files=$i
echo

echo "Total files: $total_files."

set_ratio_arrays() {
	local var_name var_val ratio_to_fsize ratio_to_1sec
	info "Ranking the information…"
	echo -n '(1 dot = 1 file)  '
	for (( i=0; i<total_files; i++)); do
		var_name=file${i}_c
		declare -n var_val=$var_name
		ratio_to_fsize=${var_val[ratio_to_fsize_pct]}

		if [ "$(echo "$ratio_to_fsize <= 0.1" | bc)" = 1 ]; then
			ratio_to_fsize_le_01+=( [$i]="$ratio_to_fsize")
		elif [ "$(echo "$ratio_to_fsize <= 0.2" | bc)" = 1 ]; then
			ratio_to_fsize_le_02+=( [$i]="$ratio_to_fsize")
		elif [ "$(echo "$ratio_to_fsize <= 0.3" | bc)" = 1 ]; then
			ratio_to_fsize_le_03+=( [$i]="$ratio_to_fsize")
		elif [ "$(echo "$ratio_to_fsize <= 0.4" | bc)" = 1 ]; then
			ratio_to_fsize_le_04+=( [$i]="$ratio_to_fsize")
		elif [ "$(echo "$ratio_to_fsize <= 0.5" | bc)" = 1 ]; then
			ratio_to_fsize_le_05+=( [$i]="$ratio_to_fsize")
		elif [ "$(echo "$ratio_to_fsize <= 1" | bc)" = 1 ]; then
			ratio_to_fsize_le_1+=( [$i]="$ratio_to_fsize")
		elif [ "$(echo "$ratio_to_fsize <= 2" | bc)" = 1 ]; then
			ratio_to_fsize_le_2+=( [$i]="$ratio_to_fsize")
		elif [ "$(echo "$ratio_to_fsize <= 5" | bc)" = 1 ]; then
			ratio_to_fsize_le_5+=( [$i]="$ratio_to_fsize")
		elif [ "$(echo "$ratio_to_fsize <= 10" | bc)" = 1 ]; then
			ratio_to_fsize_le_10+=( [$i]="$ratio_to_fsize")
		else
			ratio_to_fsize_others+=( [$i]="$ratio_to_fsize" )
		fi

		ratio_to_1sec=${var_val[ratio_to_1sec_of_playback]}
		if [ "$(echo "$ratio_to_1sec <= 0.5" | bc)" = 1 ]; then
			ratio_to_1sec_le_05+=( [$i]="$ratio_to_1sec")
		elif [ "$(echo "$ratio_to_1sec <= 1" | bc)" = 1 ]; then
			ratio_to_1sec_le_1+=( [$i]="$ratio_to_1sec")
		elif [ "$(echo "$ratio_to_1sec <= 2" | bc)" = 1 ]; then
			ratio_to_1sec_le_2+=( [$i]="$ratio_to_1sec")
		elif [ "$(echo "$ratio_to_1sec <= 3" | bc)" = 1 ]; then
			ratio_to_1sec_le_3+=( [$i]="$ratio_to_1sec")
		elif [ "$(echo "$ratio_to_1sec <= 4" | bc)" = 1 ]; then
			ratio_to_1sec_le_4+=( [$i]="$ratio_to_1sec")
		elif [ "$(echo "$ratio_to_1sec <= 5" | bc)" = 1 ]; then
			ratio_to_1sec_le_5+=( [$i]="$ratio_to_1sec")
		elif [ "$(echo "$ratio_to_1sec <= 6" | bc)" = 1 ]; then
			ratio_to_1sec_le_6+=( [$i]="$ratio_to_1sec")
		elif [ "$(echo "$ratio_to_1sec <= 9" | bc)" = 1 ]; then
			ratio_to_1sec_le_9+=( [$i]="$ratio_to_1sec")
		elif [ "$(echo "$ratio_to_1sec <= 12" | bc)" = 1 ]; then
			ratio_to_1sec_le_12+=( [$i]="$ratio_to_1sec")
		elif [ "$(echo "$ratio_to_1sec <= 20" | bc)" = 1 ]; then
			ratio_to_1sec_le_20+=( [$i]="$ratio_to_1sec")
		elif [ "$(echo "$ratio_to_1sec <= 30" | bc)" = 1 ]; then
			ratio_to_1sec_le_30+=( [$i]="$ratio_to_1sec")
		else
			ratio_to_1sec_others+=( [$i]="$ratio_to_1sec" )
		fi

		echo -n '.'

	done
	echo
	return 0
}

set_ratio_arrays
modes=( 'minmax' 'values' 'ids' 'ids_with_tags' )
mode_idx=0
until [ -v quit ]; do
	echo -e "\n\n    Mode: ${__bri}${modes[mode_idx]^^}${__s} \n"
	echo "Muxing overhead as percent of file size:"
	[ ${#ratio_to_fsize_le_01[@]} -ne 0 ] \
	&& { echo -n '<= 0.1% | '; print_${modes[mode_idx]} ratio_to_fsize_le_01; }
	[ ${#ratio_to_fsize_le_02[@]} -ne 0 ] \
	&& { echo -n '<= 0.2% | '; print_${modes[mode_idx]} ratio_to_fsize_le_02; }
	[ ${#ratio_to_fsize_le_03[@]} -ne 0 ] \
	&& { echo -n '<= 0.3% | '; print_${modes[mode_idx]} ratio_to_fsize_le_03; }
	[ ${#ratio_to_fsize_le_04[@]} -ne 0 ] \
	&& { echo -n '<= 0.4% | '; print_${modes[mode_idx]} ratio_to_fsize_le_04; }
	[ ${#ratio_to_fsize_le_05[@]} -ne 0 ] \
	&& { echo -n '<= 0.5% | '; print_${modes[mode_idx]} ratio_to_fsize_le_05; }
	[ ${#ratio_to_fsize_le_1[@]} -ne 0 ] \
	&& { echo -n '  <= 1% | '; print_${modes[mode_idx]} ratio_to_fsize_le_1; }
	[ ${#ratio_to_fsize_le_2[@]} -ne 0 ] \
	&& { echo -n '  <= 2% | '; print_${modes[mode_idx]} ratio_to_fsize_le_2; }
	[ ${#ratio_to_fsize_le_5[@]} -ne 0 ] \
	&& { echo -n '  <= 5% | '; print_${modes[mode_idx]} ratio_to_fsize_le_5; }
	[ ${#ratio_to_fsize_le_10[@]} -ne 0 ] \
	&& { echo -n ' <= 10% | '; print_${modes[mode_idx]} ratio_to_fsize_le_10; }
	[ ${#ratio_to_fsize_others[@]} -ne 0 ] \
	&& { echo -n '  > 10% | '; print_${modes[mode_idx]} ratio_to_fsize_others; }
	[ "${modes[mode_idx]}" = minmax ] && {
		echo 'Peculiarities in unusual: AR: aspect ratio is not 16:9'
	}
	echo

	echo "Muxing overhead as seconds worth of playback:"
	[ ${#ratio_to_1sec_le_05[@]} -ne 0 ] \
	&& { echo -n '<= 0.5 | '; print_${modes[mode_idx]} ratio_to_1sec_le_05; }
	[ ${#ratio_to_1sec_le_1[@]} -ne 0 ] \
	&& { echo -n '  <= 1 | '; print_${modes[mode_idx]} ratio_to_1sec_le_1; }
	[ ${#ratio_to_1sec_le_2[@]} -ne 0 ] \
	&& { echo -n '  <= 2 | '; print_${modes[mode_idx]} ratio_to_1sec_le_2; }
	[ ${#ratio_to_1sec_le_3[@]} -ne 0 ] \
	&& { echo -n '  <= 3 | '; print_${modes[mode_idx]} ratio_to_1sec_le_3; }
	[ ${#ratio_to_1sec_le_4[@]} -ne 0 ] \
	&& { echo -n '  <= 4 | '; print_${modes[mode_idx]} ratio_to_1sec_le_4; }
	[ ${#ratio_to_1sec_le_5[@]} -ne 0 ] \
	&& { echo -n '  <= 5 | '; print_${modes[mode_idx]} ratio_to_1sec_le_5; }
	[ ${#ratio_to_1sec_le_6[@]} -ne 0 ] \
	&& { echo -n '  <= 6 | '; print_${modes[mode_idx]} ratio_to_1sec_le_6; }
	[ ${#ratio_to_1sec_le_9[@]} -ne 0 ] \
	&& { echo -n '  <= 9 | '; print_${modes[mode_idx]} ratio_to_1sec_le_9; }
	[ ${#ratio_to_1sec_le_12[@]} -ne 0 ] \
	&& { echo -n ' <= 12 | '; print_${modes[mode_idx]} ratio_to_1sec_le_12; }
	[ ${#ratio_to_1sec_le_20[@]} -ne 0 ] \
	&& { echo -n ' <= 20 | '; print_${modes[mode_idx]} ratio_to_1sec_le_20; }
	[ ${#ratio_to_1sec_le_30[@]} -ne 0 ] \
	&& { echo -n ' <= 30 | '; print_${modes[mode_idx]} ratio_to_1sec_le_30; }
	[ ${#ratio_to_1sec_others[@]} -ne 0 ] \
	&& { echo -n '  > 30 | '; print_${modes[mode_idx]} ratio_to_1sec_others; }

	[ "${modes[mode_idx]:0:2}" = id ] && print_id_legend

	[ $((++mode_idx)) -eq ${#modes[@]} ] && mode_idx=0

	echo -e "\n${__g}<${__s}Space${__g}>${__s} to switch mode, ${__g}<${__s}Q${__g}>${__s} to quit."
	read -n1 -s
	[[ "$REPLY" = @(q|Q) ]] && quit=t && echo
done

exit 0
