#! /usr/bin/env bash

set -feE
. "$(dirname "$0")/../lib/bahelite/bahelite.sh"
. "$(dirname "$0")/../lib/gather_file_info.sh"

 # As in nadeshiko.sh, the units are
#  bit rates: kbps
#       size: MiB
#   duration: human readable


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
	echo -en "size: ${__bri}${minval%\.*}"
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
	echo -en "duration: ${__bri}${minval}"
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
	echo -en "vbitrate: ${__bri}${minval}"
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
		&& echo -en "${__bri}(${!unusual_ar[@]})${__s}"

	[ ${#unusual_chroma[@]} -ne 0 ] \
		&& echo -en " ${__r}not_yuv420${__s}" \
		&& echo -en "${__bri}(${!unusual_chroma[@]})${__s}"

	[ ${#unusual_bit_depth[@]} -ne 0 ] \
		&& echo -en " ${__r}not_8bit${__s}" \
		&& echo -en "${__bri}(${!unusual_bit_depth[@]})${__s}"

	[ ${#unusual_vcodec_profile[@]} -ne 0 ] \
		&& echo -en " ${__r}vc_profile${__s}" \
		&& echo -en "${__bri}(${!unusual_vcodec_profile[@]})${__s}"
	return 0
}

# $1 – array name
print_ids() {
	declare -n arr="$1"
	local i val
	for i in ${!arr[@]}; do
		echo -en " ${__bri}$i${__s}"
	done
	echo
	return 0
}

# $1 – array name
print_values() {
	declare -n arr="$1"
	local i val
	for i in ${!arr[@]}; do
		echo -en " ${__bri}${arr[i]}${__s}"
	done
	echo
	return 0
}

rm -rf "$MYDIR/container_ratios_data"
mkdir container_ratios_data
i=-1
# set -x
while IFS= read -r -d '' ; do
	gather_file_info "$REPLY" $((++i)) || exit $?
	for varname in ${!file*}; do
		[[ "$varname" =~ ^file${i}_ ]] && {
			declare -n val=$varname
			echo "${varname#file${i}_} = $val" >> container_ratios_data/$i
		}
	done
done  < <(find -maxdepth 1 -iname "*.mp4" -printf "%P\0")
total_files=$i

info "Total files: $total_files."

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
	echo -e "\n\n    Mode: ${__bri}${modes[mode_idx]^^}${__s} \n"
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
	read -n1 -s
	[[ "$REPLY" = @(q|Q) ]] && quit=t && echo
done

exit 0
