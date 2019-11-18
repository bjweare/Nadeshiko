#  Should be sourced.

#  10_after_encoding.sh
#  Nadeshiko module that holds functions of various purposes for the stage
#  after video clip was encoded (when the program may finish or do a re-run).
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh


print_stats() {
	local stats
	local pass1_s
	local pass1_hms
	local pass2_s
	local pass2_hms
	local pass1_and_pass2_s
	local pass1_and_pass2_hms

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
	declare -g  muxing_overhead_antiovershoot
	declare -g  new_file_size_B
	declare -g  max_size_B
	declare -g  min_esp_unit
	declare -g  esp_unit
	declare -g  overshot_times

	local  filesize_overshoot
	local  previous_muxing_overhead_antiovershoot
	local  muxing_overhead_antiovershoot_in_esp

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