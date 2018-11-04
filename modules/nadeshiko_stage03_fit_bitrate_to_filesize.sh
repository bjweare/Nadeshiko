#  Should be sourced.

#  stage03_fit_bitrate_to_filesize.sh
#  Nadeshiko module, that finds an appropriate bitrate and resolution
#  for a given file size.
#  deterenkelt © 2018
#
#  For licence see nadeshiko.sh


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
	infon "Trying $vbitrate_pretty${audio_info:-} @"
	if [ -v scale ]; then
		#  Forced scale
		echo -n "${scale}p.  "
	elif [ -v crop ]; then
		echo -n "Cropped.  "
	elif [ $current_bitres_profile -ne $starting_bitres_profile ]; then
		#  Going lowres
		echo -n "${current_bitres_profile}p.  "
	else
		echo -n 'Native.  '
	fi
	if [ -v audio ]; then
		audio_track_size_bits=$((  ${duration[total_s]} * abitrate_bits  ))
	else
		audio_track_size_bits=0
	fi
	space_for_video_track=$((   max_size_bits
	                          - audio_track_size_bits
	                          - container_own_size_pct_bits  ))
	max_fitting_vbitrate_bits=$((    space_for_video_track
	                               / ${duration[total_s]}    ))
	echo "Have space for $((max_fitting_vbitrate_bits/1000))k${audio_info:-}."
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
	local varname="$1" correction_type origres_corr cropres_corr \
	      profile_res var_pretty var_bits
	declare -n var=$varname
	var=${var//k/*1000}
	var=${var//M/*1000*1000}
	var=$(( $var ))
	shift  # positional parameters become correction types
	for correction_type in "$@"; do
		case "$correction_type" in
			#  orig_res should be first!
			orig_res)
				#  Tricky formula for non-standard resolutions, which
				#  do not actually exists in out table.
				starting_profile_res_total_px=$((
				    $starting_bitres_profile**2 *16/9
				))
				origres_corr=$(  \
				    echo "scale=4;   $orig_res_total_px \
				                   / $starting_profile_res_total_px" \
				    | bc )
				var=$(echo "$var * $origres_corr" | bc)
				autocorr_vbitrate=t
				;;
			crop_res)
				crop_res_total_px=$((crop_w * crop_h))
				cropres_corr=$(echo "scale=4;   $crop_res_total_px \
				                              / $orig_res_total_px" \
				                | bc )
				[ "$cropres_corr" = '1' ] \
					&& unset crop \
					|| var=$(echo "$var * $cropres_corr" | bc)
				autocorr_vbitrate=t
				;;
			minimal_bitrate)
				var=$(echo "$var * $minimal_bitrate_pct / 100" | bc)
				# This counts as something, that the user implies to use.
				# Variations in minimal bitrate should be small,
				# so there’s no reason to accentuate attention on it.
				;;
		esac
	done
	var=${var%.*} # dropping the fractional part. bc can’t round anyway.
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
#  $1 – resolution of some bitres profile, e.g. 1080, 720, 576…
#
set_bitres_profile() {
	local res="$1"
	# Setting active bitrate–resolution profile.
	declare -gn bitres_profile="bitres_profile_${res}p"
	[ $current_bitres_profile -ne $starting_bitres_profile ] \
		&& autocorr_scale=t autocorr_vbitrate=t autocorr_abitrate=t
	#  If vbitrate or abitrate are already set,
	#  that means they were forced though the command line.
	[ ! -v forced_vbitrate ] && {
		desired_vbitrate=${bitres_profile[${ffmpeg_vcodec}_desired_bitrate]}
		recalc_bitrate 'desired_vbitrate' \
		               ${needs_bitrate_correction_by_origres:+orig_res} \
		               ${needs_bitrate_correction_by_cropres:+crop_res}
		info "${res}p: Setting desired vbitrate to $desired_vbitrate_pretty."
		vbitrate=$desired_vbitrate
		vbitrate_bits=$desired_vbitrate_bits
		minimal_vbitrate=$desired_vbitrate
		recalc_bitrate 'minimal_vbitrate' minimal_bitrate
		info "${res}p: Setting minimal vbitrate to $minimal_vbitrate_pretty."
	}
	[ -v audio ] \
	&& [ ! -v forced_abitrate ] \
	&& {
		desired_abitrate=${bitres_profile[audio_desired_bitrate]}
		recalc_bitrate 'desired_abitrate'  # only to set _bits, actually
		info "${res}p: Setting desired abitrate to $desired_abitrate_pretty."
		abitrate=$desired_abitrate
		abitrate_bits=$desired_abitrate_bits
	}
	#  Forced bitrates are already set,
	#  we only need to calculate _bits variables for them.
	[ -v forced_vbitrate ] && recalc_bitrate 'vbitrate'
	[ -v forced_abitrate ] && recalc_bitrate 'abitrate'
	return 0
}


 # Switches off flags in our_options array for the current conditions
#  The variables in this code just had to be local, so it has become
#  yet another function.
#
unset_our_options() {
	local cur_video_track_size max_video_track_size track_size_difference \
	      two_seconds_of_playback_size one_tenth_of_duration_size
	# Avoid an eternal cycle when the horrible happens.
	[ $space_for_video_track -lt 0 ] && {
		unset our_options[seek_maxfit_here]
		unset our_options[lower_resolution]
	}
	[ -v forced_vbitrate ] && unset our_options[seek_maxfit_here]
	# Properly downscaling crop resolution isn’t implemented yet.
	[ -v crop ] && unset our_options[lower_resolution]
	[ -v forced_scale ] && unset our_options[lower_resolution]
	[ -v bitrates_locked_on_desired ] && {
		# Allow marginal deviations
		# If vbitrate differs from max_fitting… by not more than
		# - space needed for two seconds of video playback;
		# - space needed for 1/10 of total duration;
		# then let it stay within current resolution,
		# otherwise lock and go a resolution lower.
		cur_video_track_size=$(( vbitrate_bits * ${duration[total_s]} ))
		max_video_track_size=$((    max_fitting_vbitrate_bits
		                          * ${duration[total_s]}        ))
		track_size_difference=$((   cur_video_track_size
		                          - max_video_track_size  ))
		two_seconds_of_playback_size=$(( max_fitting_vbitrate_bits * 2 ))
		one_tenth_of_duration_size=$(( max_video_track_size / 10 ))

		[    $track_size_difference -lt $two_seconds_of_playback_size \
		  -o $track_size_difference -lt $one_tenth_of_duration_size   ] \
			|| unset our_options[seek_maxfit_here]
	}
	return 0
}


 # Finds appropriate video bitrate and resolution for the encode.
#  Takes into account bitrate coefficients and constraints.
#
fit_bitrate_to_filesize() {
	# As we may re-run, let’s operate on a local copy.
	local closest_lowres_index=$closest_lowres_index cannot_fit
	info "Calculating, how we fit… "
	max_size_in_bytes=$max_size
	max_size_in_bytes=${max_size_in_bytes//k/*$kilo}
	max_size_in_bytes=${max_size_in_bytes//M/*$kilo*$kilo}
	max_size_in_bytes=${max_size_in_bytes//G/*$kilo*$kilo*$kilo}
	max_size_in_bytes=$(($max_size_in_bytes))
	max_size_bits=$((max_size_in_bytes*8))
	container_own_size_pct_bits=$((    max_size_bits
	                                 * container_own_size_pct
	                                 / 100                 ))

	if [ -v scale ]; then
		starting_bitres_profile="$scale"
	elif [ -v closest_res ]; then
		starting_bitres_profile="$closest_res"
	else
		starting_bitres_profile="$orig_height"
	fi
	current_bitres_profile="$starting_bitres_profile"
	set_bitres_profile "$starting_bitres_profile"
	info "Starting bitres profile: ${starting_bitres_profile}p."
	milinc
	recalc_vbitrate_and_maxfitting

	 # What can be done, if bitrates × duration do not fit max_size.
	#  I find this array a genius invention, the code was a mess without it.
	#
	declare -A our_options=(
		[seek_maxfit_here]=t  # Until vbitrate hits minimal in the current
		                      # resolution profile.
		[lower_resolution]=t  # Change resolution profile.
	)

	 # Are we already good?
	#  If not, can we scale to lower resolutions?
	#
	until [ $vbitrate_bits -le $max_fitting_vbitrate_bits  -o  -v cannot_fit ]
	do
		unset_our_options
		#  The flexibility of this code is amazing – we can have fixed
		#  audio bitrate set with, say, ab200k and still have vbitrate go
		#  round and around until the overall size fits to max_size!

		if [ -v our_options[seek_maxfit_here] ]; then
			if	((     max_fitting_vbitrate_bits >= minimal_vbitrate_bits
				    && max_fitting_vbitrate_bits <= desired_vbitrate_bits  ))
			then
				vbitrate=$max_fitting_vbitrate_bits
				recalc_vbitrate_and_maxfitting
			else
				unset our_options[seek_maxfit_here]
			fi
		elif [ -v our_options[lower_resolution] ]; then
			if (( closest_lowres_index < ${#known_res_list[@]} )); then
				current_bitres_profile=${known_res_list[closest_lowres_index]}
				mildrop
				info "Trying lower resolution ${current_bitres_profile}p… "
				set_bitres_profile $current_bitres_profile
				let 'closest_lowres_index++ || 1'
				milinc
				our_options[seek_maxfit_here]=t
				recalc_vbitrate_and_maxfitting
			else
				#  Lower resolutions are depleted.
				unset our_options[lower_resolution]
			fi
		else
			cannot_fit=t
		fi
	done

	mildrop
	[ -v cannot_fit ] && err "Cannot fit ${duration[ts_short_no_ms]} into $max_size."

	[ $current_bitres_profile -ne $starting_bitres_profile ] && {
		scale=$current_bitres_profile

		 # Only if we went a resolution down – assign better, i.e. maximum
		#  fitting resolution to vbitrate. When we already know that the video
		#  *could* make use of more bitrate, it should be allowed, but other-
		#  wise avoided – if the video already fits well *in the native* reso-
		#  lution, allowing vbitrate have maxfitting… value would only bloat,
		#  possibly.
		#
		[ $vbitrate_bits -lt $max_fitting_vbitrate_bits ] && {
			old_vbitrate_pretty="$vbitrate_pretty"
			vbitrate=$max_fitting_vbitrate_bits
			recalc_bitrate 'vbitrate'
			[ "$old_vbitrate_pretty" != "$vbitrate_pretty" ] && {
				#  Showing the info message only if the difference was big
				#  enough to be shown in “pretty” values, visible to the user.
				info "Headpat to the poor downscaled video:
				      vbitrate=${__y}${__b}$vbitrate_pretty${__s}"
			}
		}
	}

	return 0
}


return 0