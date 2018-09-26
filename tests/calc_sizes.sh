#! /usr/bin/env bash

#  How much size should a video be, if…

 # Calculates estimated file size
#  $1 – max size
#  $2 – kilo
#  $3 – reserved %
#  $4 – vbitrate
#  $5 – abitrate
#  $6 – duration
#
calc_size(){
	local max_container_size="$1" \
                        kilo="$2" \
                reserved_pct="${3%\%}" \
	                vbitrate="$4" \
	                abitrate="$5" \
	                duration="$6"

	max_container_size=${max_container_size//k/*$kilo}
	max_container_size=${max_container_size//M/*$kilo*$kilo}
	max_container_size=${max_container_size//G/*$kilo*$kilo*$kilo}
	max_container_size=$(( $max_container_size*8 ))
	reserved_for_container=$(( max_container_size*$reserved_pct/100 ))

	# Our target bitrates are…
	vbitrate=${vbitrate//k/*1000}
	vbitrate=${vbitrate//M/*1000*1000}
	vbitrate=${vbitrate//G/*1000*1000*1000}
	vbitrate=$(( $vbitrate ))

	abitrate=${abitrate//k/*1000}
	abitrate=${abitrate//M/*1000*1000}
	abitrate=${abitrate//G/*1000*1000*1000}
	abitrate=$(( $abitrate ))

	vbitrate_space_required=$(( vbitrate * duration ))
	abitrate_space_required=$(( abitrate * duration ))
	total_space_required=$(( vbitrate_space_required + abitrate_space_required ))

	echo -e "Size: $1. Duration: $duration s.\n"
	(
		echo -e  "  ­    \t B \t kB \t KiB \t MB \t MiB"

		echo -en "Video"
		echo -en "\t $((vbitrate_space_required/8))"  # B
		echo -en "\t $((vbitrate_space_required/8/1000))"  # kB
		echo -en "\t $((vbitrate_space_required/8/1024))"  # KiB
		echo -en "\t $(echo "scale=2; $vbitrate_space_required/8/1000/1000"|bc)"  # MB
		echo -e  "\t $(echo "scale=2; $vbitrate_space_required/8/1024/1024"|bc)"  # MiB

		echo -en "Audio"
		echo -en "\t $((abitrate_space_required/8))"  # B
		echo -en "\t $((abitrate_space_required/8/1000))"  # kB
		echo -en "\t $((abitrate_space_required/8/1024))"  # KiB
		echo -en "\t $(echo "scale=2; $abitrate_space_required/8/1000/1000"|bc)"  # MB
		echo -e  "\t $(echo "scale=2; $abitrate_space_required/8/1024/1024"|bc)"  # MiB

		echo -en "Total"
		echo -en "\t $((total_space_required/8))"  # B
		echo -en "\t $((total_space_required/8/1000))"  # kB
		echo -en "\t $((total_space_required/8/1024))"  # KiB
		echo -en "\t $(echo "scale=2; $total_space_required/8/1000/1000"|bc)"  # MB
		echo -e  "\t $(echo "scale=2; $total_space_required/8/1024/1024"|bc)"  # MiB
	) | column -t -s $'\t'

	echo
	[ $total_space_required -le $((max_container_size - reserved_for_container)) ] \
		&& echo -e "Fitting – YES" \
		|| echo -e "Fitting – NO"
	echo

	echo -n "Reserved $reserved_pct% from $1: "
	echo "$((reserved_for_container/8/1024)) KiB or $((reserved_for_container/8/1000)) KB"
	# free_space=$(( max_container_size - reserved_for_container ))
}

[[ "$1" =~ ^(-h|--help)$  || $# -eq 0 ]] && {
	cat <<-EOF
	Usage: ./calc_sizes <size, 10M> <1000|1024> <reserved %> <vbitrate> <abitrate> <duration, seconds>
	EOF
	exit 0
}

[ $# -ne 0 ] && calc_size  "$@"

return 0
