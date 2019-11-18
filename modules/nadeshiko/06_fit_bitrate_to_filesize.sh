#  Should be sourced.

#  06_fit_bitrate_to_filesize.sh
#  Nadeshiko module, that applies a recursive heuristic algorithm to find
#  an appropriate bitrate and resolution for the video clip, considering
#  the requested file size.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh


 # This is the most complex part of the entire program. It feels like the code
#    here could be organised better, however it was already revised three
#    times and what is below represents the clearest idea on how to maintain
#    this all small and understandable. These two requirements are crucial,
#    because there are parts of the code that it calls recursively. You have
#    to hold all the nuances and execution routes in your head as you go, so
#    making thing clear enough to hold revisions was already an achievement
#    in itself.
#  But don’t worry – the deeper it gets, the more thoroughly are written the
#    comments. So at least for an understanding of how it works, the code
#    must be quite clear. Just don’t get an idea that it would be easy to
#    rewrite this.
#  The last revise has revealed a limit of flexibility. So far the code fits
#    the idea of it tightly, but if some feature – that is not known now –
#    would be needed, it may be necessary to reimplement this module entirely
#    in a new way. By the “unknown features” are meant post-“it fits!” opti-
#    misations (like the vbitrate “headpats” using the gaps between profile
#    max and min, like fitting better audio if space permits for it), for such
#    optimisations call for a recalculation of something, that was considered
#    already “stabilised” once the “it fits!” stage is finished.
#  What a next revise would have to do to offer more flexibility for the code
#    is to:
#    - further atomise basic operations on the bitrates, down to helper utils
#      (though their number would grow, which is bad);
#    - separate the stages of “it fits!” and “now let’s look, how to optimise
#      the video clip better”. The latter stage shouldn’t break anything from
#      the former, and to achieve that, the former stage should be remade so
#      as to create not the “finished” set of values, but rather a volatile
#      “intermediate” set. The current code was planned and implemented with
#      an assumption, that the optimal vbitrate and abitrate would be found in
#      one go, so the “let’s optimise” stage is kind of hacked up on top of it.
#      Thus that “intermediate” set of values is what the current code is to-
#      tally lacking. The “final” set then should be defined only at the end
#      of the “let’s optimise stage” (which is the second and the last stage,
#      as we’re charting it now).
#


 # Calculates the maximum amount of video bitrate, that fits
#  into max_size. Works only on $vbitrate and $abitrate, hence
#  no bitrate corrections, except for 100k decrement, should be
#  used here.
#
recalc_space() {
	declare -g space_for_video_track   #  used in unset_our_options()

	local vidres
	local audio_info
	local padding_per_duration
	local duration_secs
	local old_duration_secs
	local audio_track_expected_overhead
	local audio_track_size

	milinc

	if [ -v audio ]; then
		recalc_acodec_size_deviation
		audio_track_size=$((    duration[total_s] * abitrate
		                      + audio_track_expected_overhead  ))
	else
		audio_track_size=0
	fi

	recalc_muxing_overhead
	space_for_video_track=$((   max_size_bits
	                          - audio_track_size
	                          - muxing_overhead   ))

	max_fitting_vbitrate=$((    space_for_video_track
	                          / duration[total_s]      ))


	[ -v audio ] && audio_info=" / $(pretty "$abitrate")"
	if [ -v scale ]; then
		#  Forced scale
		vidres="${scale}p"
	elif [ -v crop ]; then
		vidres="Cropped"
	elif (( current_bitres_profile != starting_bitres_profile )); then
		#  Going lowres
		vidres="${current_bitres_profile}p"
	else
		vidres='Native'
	fi
	infon "Trying $(pretty "$vbitrate")${audio_info:-} @${vidres}.  "
	echo "Have space for $(pretty "$max_fitting_vbitrate")${audio_info:-}."

	[ ! -v forced_vbitrate  ]  \
	&& [ -v src_v[bitrate]  ]  \
	&& [ -v orig_vcodec_same_as_enc ]  \
	&& (( max_fitting_vbitrate > src_v[bitrate] )) && {
		info "Can fit original ${srv_v[bitrate]} kbps!"
		vbitrate=${src_v[bitrate]}
	}

	mildec
	return 0
}


 # Calculates overhead for the audio track. It is not specific value, rather
#  a value to be added as is, as the size deviation from the tables are al-
#  ready specific and based on the bitrate.
#
recalc_acodec_size_deviation() {
	declare -g audio_track_expected_overhead
	local -n padding_per_duration=${ffmpeg_acodec}_${acodec_profile}_size_deviations_per_duration
	local duration_secs  durations_high_to_low

	durations_high_to_low=$(
		IFS=$'\n'; echo "${!padding_per_duration[*]}" | tac  # sic!
	)
	for duration_secs in $durations_high_to_low; do
		(( duration[total_s] <= duration_secs )) \
			&& break  \
			|| continue
	done
	audio_track_expected_overhead=$(
		echo "scale=3; ao = ${padding_per_duration[duration_secs]} * $abitrate;  \
		      scale=0; ao/1"  | bc
	)
	info "Expected audio track overhead: $(pretty "$audio_track_expected_overhead")"
	return 0
}


recalc_muxing_overhead() {
	declare -g  muxing_overhead
	declare -g  frame_count
	declare -g  esp_unit

	local  frame_count_border
	local  esp_to_reserve=0

	info "Calculating the muxing overhead:"
	milinc
	#  Sic! Iterating indices from low to high
	for frame_count_border in ${!container_space_reserved_frames_to_esp[*]}; do
		(( frame_count > frame_count_border ))  \
			&& esp_to_reserve=${container_space_reserved_frames_to_esp[frame_count_border]}
	done

	#  ESP is an equivalent of one second of playback (A+V). Used in predic-
	#  ting muxing overhead. See “Muxing overhead” on the wiki.
	esp_unit=$vbitrate
	[ -v audio ] && let "esp_unit += $abitrate, 1"
	info "Reserving $esp_to_reserve ESP  (1 ESP = $(pretty "$esp_unit"))"
	muxing_overhead=$( echo "scale=2; ovhead = $esp_to_reserve * $esp_unit;  \
	                         scale=0; ovhead / 1" | bc
	)
	let "muxing_overhead += ${filesize_antiovershoot:-0}, 1"
	info "Anti-overshoot padding: $(pretty "${filesize_antiovershoot:-0}")"
	info "Expected muxing overhead: $(pretty "$muxing_overhead")"
	mildec
	return 0
}


#  $1 – variable name, which value should be converted from the shortened
#       form (999k) to a number (999 999)
to_bits() {
	local varname="${1#\*}"
	local -n varval=$varname
	varval=${varval//k/*1000}
	varval=${varval//M/*1000*1000}
	varval=$(( $varval ))
	return 0
}


#  $1 – some number to shorten into 999k
pretty() {
	local var="$1"
	 # Setting _pretty variable for display
	#
	#  M’s cut too much, seeing 2430k would be more informative, than “2M”.
	#  “Is that 2000k or 2900k?” Those 900k make a difference.
	#
	# if [[ "$var" =~ .......$ ]]; then
	# 	var="$((var/1000000))M"
	# el
	if [[ "$var" =~ ....$ ]]; then
		var="$((var/1000))k"
	fi
	#  If $var bears a five-digit number, introduce a thousand separator: ’
	[[ "$var" =~ ^([0-9]{2,})([0-9]{3})k$ ]] && {
		var="${BASH_REMATCH[1]}’${BASH_REMATCH[2]}k"
	}
	echo "$var"
	return 0
}


#  $1 – some xbitrate variable, all numbers.
apply_correction() {
	declare -g autocorrected_vbitrate
	local  varname="${1#\*}" correction_type  origres_corr  cropres_corr  \
	       orig_res_total_px=${src_v[resolution_total_px]}  \
	       cropres_total_px
	local -n varval=$varname
	shift  # remaining positional parameters become correction types
	for correction_type in "$@"; do
		case "$correction_type" in
			#  orig_res should be first!
			by_orig_res)
				#  Tricky formula for non-standard resolutions.
				#  Bitres profiles use 16×9.
				starting_profile_res_total_px=$((
				    starting_bitres_profile**2 *16 /9
				))
				origres_corr=$(
					echo "scale=4;   $orig_res_total_px  \
					               / $starting_profile_res_total_px" | bc
				)
				varval=$(
					echo "scale=4; vv = $varval * $origres_corr;  \
					      scale=0; vv/1" | bc
				)
				autocorrected_vbitrate=t
				;;
			by_crop_res)
				crop_res_total_px=$((crop_w * crop_h))
				cropres_corr=$(
					echo "scale=4;   $crop_res_total_px  \
					               / $orig_res_total_px" | bc
				)
				[ "$cropres_corr" = '1' ]  \
					&& unset crop  \
					|| varval=$(echo "scale=4; vv = $varval * $cropres_corr;  \
					                  scale=0; vv/1" | bc )
				autocorrected_vbitrate=t
				;;
			to_minimal_bitrate)
				varval=$(
					echo "scale=4; vv =    $varval  \
					                     * $minimal_bitrate_pct  \
					                     / 100;  \
					      scale=0; vv/1"  | bc
				)
				#  This counts as something, that the user implies to use.
				#  Variations in minimal bitrate should be small,
				#  so there’s no reason to accentuate attention on it.
				;;
		esac
	done
	return 0
}


 # When resolution profile is set initially or changes afterwards,
#  this function is called to assign
#    - desired_vbitrate;
#    - minimal_vbitrate;
#    - acodec_profile;
#    to the values from the bitrate-resolution profile specified via $1.
#  $1 – resolution of some bitres profile, e.g. 1080, 720, 576…
#
 # After the desired values, vbitrate and abitrate are set. They are the
#  “working” values – max_fitting_vbitrate is calculated with them,
#  and it is vbitrate, that’s checked against max_fitting_vbitrate.
#
set_bitres_profile() {
	declare -g  bitres_profile
	declare -g  vbitrate
	declare -g  abitrate
	declare -g  autocorrected_scale
	declare -g  autocorrected_vbitrate
	declare -g  autocorrected_abitrate
	declare -g  acodec_profile

	local res="$1"
	local extra_colour

	info "${res}p: loading profile"
	milinc

	# Setting active bitrate–resolution profile.
	declare -gn bitres_profile="bitres_profile_${res}p"
	(( current_bitres_profile != starting_bitres_profile )) && {
		autocorrected_scale=t
		autocorrected_vbitrate=t
		autocorrected_abitrate=t
	}

	[ -v forced_vbitrate ] && {
		to_bits '*vbitrate'
		return 0
	}

	 # If bitrates aren’t locked, define desired and minimal values for
	#  the curent profile.
	#
	#  Setting desired_vbitrate
	desired_vbitrate="${bitres_profile[${ffmpeg_vcodec}_desired_bitrate]}"
	to_bits '*desired_vbitrate'
	apply_correction '*desired_vbitrate' \
	                 ${needs_bitrate_correction_by_origres:+by_orig_res}  \
	                 ${needs_bitrate_correction_by_cropres:+by_crop_res}
	[ -v autocorrected_vbitrate ] && extra_colour="${__bri}${__y}"
	info "desired_vbitrate = ${extra_colour:-}$(pretty "$desired_vbitrate")${__s}."
	#  Setting minimal_vbitrate
	minimal_vbitrate=$desired_vbitrate
	apply_correction '*minimal_vbitrate'  \
	                 'to_minimal_bitrate'

	info "minimal_vbitrate = $(pretty "$minimal_vbitrate")."
	#  Setting vbitrate, that will take values from desired to minimal
	#  until it fits to the file size or bitres profile changes.
	vbitrate=$desired_vbitrate

	[ -v audio ] && {
		#  The value in {ffmpeg_acodec}_profile looks like a bitrate
		#  but it is but a profile name, that speaks about what median
		#  bitrate this profile aims for. Some audio codecs use VBR, some CBR,
		#  some codecs take precise values, some vaguely set “quality”.
		acodec_profile=${bitres_profile[${ffmpeg_acodec}_profile]}
		#  acodec_profile must be remembered as it is, so that at the encoding
		#  stage the ffmpeg arguments of that that profile could be retrieved.
		#  And for calculations there is  the abitrate  variable.
		abitrate=$(( acodec_profile * 1000))
		info "        abitrate = $(pretty "$abitrate")."
	}

	mildec
	return 0
}


 # Switches off flags in our_options array for the current conditions.
#
unset_our_options() {
	local  cur_video_track_size
	local  max_video_track_size
	local  track_size_difference
	local  total_playback_minutes
	local  allowed_margin

	#  Avoid an eternal cycle when the horrible happens.
	(( space_for_video_track < 0 )) && {
		unset our_options[seek_maxfit_here]  \
		      our_options[lower_resolution]
	}

	[ -v forced_vbitrate ]  \
		&& unset our_options[seek_maxfit_here]

	 # Disallow scaling when crop is requested.
	#  Cropped videos are very specific in the regard of distributing
	#  bitrate, so the generic recommendations are not applicable to them.
	#  Allowing to go down a resolution lower, when a clip is to be cropped,
	#  would require a big number of tests.
	#
	[ -v crop ]  \
		&& unset our_options[lower_resolution]

	[ -v forced_scale ]  \
		&& unset our_options[lower_resolution]

	#  If the scene is dynamic, the video bitrate is locked on desired.
	[ -v vbitrate_locked_on_desired ] && {
		#  Allow marginal deviations
		#  If vbitrate differs from max_fitting_vbitrate by not more than
		#  space needed for two seconds of video playback per minute
		#  (duration < 1 min equaled to 1 min), then let it stay within
		#  the current resolution, otherwise lock and go a resolution lower.
		cur_video_track_size=$(( vbitrate * duration[total_s]  ))

		max_video_track_size=$((    max_fitting_vbitrate
		                          * duration[total_s]  ))

		track_size_difference=$((   cur_video_track_size
		                          - max_video_track_size  ))

		total_playback_minutes=$(( ${duration[h]}*60 + ${duration[m]} ))

		(( total_playback_minutes == 0 )) && total_playback_minutes=1
		allowed_margin=$((   2*max_fitting_vbitrate
		                   * total_playback_minutes    ))

		(( track_size_difference > allowed_margin  ))  \
			&& unset our_options[seek_maxfit_here]
	}
	return 0
}


 # Returns 0, if the source audio is of a higher quality, than
#  what it is to be encoded with by the bitres profile setting.
#
is_it_sensible_to_use_better_abitrate() {
	local  acodec_name_as_formats_varname
	local  acodec_name
	local  known_formats
	local  known_format
	local  delimiter
	local  format_per_se
	local  format_profile_per_se
	local  format_matches
	local  source_audio_format_is_unknown
	local  source_audio_stereo_equiv_bitrate
	local  source_acodec_profiles
	local  source_acodec_default_profile
	local  trying_a_higher_audio_profile_makes_sense
	local  audio_profile
	local  top_acodec_profile

	[ -v src_a[format]  ] || {
		denied 'Audio track format is missing in the source metadata.'
		return 1
	}
	#  If it’s lossless, it’s better by definition.
	[ -v src_a[is_lossless]  ]	&& {
		info "Audio track in the source is lossless.
		      Trying a higher audio bitrate makes sense!"
		return 0
	}

	#  If it’s not lossless, then do we recognise the audio format
	#  (and profile format, if necessary)?
	shopt -s nocasematch  # so that VORBIS == Vorbis
	for acodec_name_as_formats_varname in ${!acodec_name_as_formats*}; do
		#  Remembering acodec’s name for the later check on bitrate.
		acodec_name=${acodec_name_as_formats_varname#*formats_}
		unset -n format_profile_delimiter
		local -n known_formats=$acodec_name_as_formats_varname
		[ -v ${acodec_name_as_formats_varname/acodec_/acodec_delimiter_for_} ]  && {
			#  Delimiter between format and format profile, e.g. colon
			#  in “AAC:LC”. Format profile may or may not be present.
			local -n delimiter=${acodec_name_as_formats_varname/acodec_/acodec_delimiter_for_}
		}
		#  This evaluates per each known acodec
		for known_format in "${known_formats[@]}"; do
			format_per_se="${known_format%${delimiter:-no delim}*}"
			format_profile_per_se="${known_format#*${delimiter:-no delim}}"
			[[ "${src_a[format]}" = "$format_per_se" ]] && {
				#  If at least format did already match, then let’s see, if
				#  there’s also format profile to be compared…
				if [ "$format_profile_per_se" = "$known_format" ]; then
					#  No format profile, a match by format alone is enough.
					format_matches=t
					#  If there would be format profile, then it should be
					#  printed. If not…
					unset format_profile_per_se
					break 2
				else
					#  And if there is a delimiter, we need to check it too.
					[ -v src_a[format_profile]  ] || {
						denied 'The audio track in the source must have had a format profile,
						        but it wasn’t present and therefore cannot be checked.'
						shopt -u nocasematch
						return 1
					}
					[[ "${src_a[format_profile]}" = "$format_profile_per_se" ]] && {
						format_matches=t
						break 2
					}
				fi
			}

		done
	done
	shopt -u nocasematch

	if [ -v format_matches ]; then
		info "Source audio codec is equivalent to an FFmpeg’s codec with…"
		milinc
		msg "name: $acodec_name"
		msg "format: $format_per_se"
		[ -v format_profile_per_se ]  \
			&& msg "format profile: $format_profile_per_se"
		mildec
	else
		info "Source audio format is not known to Nadeshiko. It may still pass
		      the second check, but the plank will be set extra high."
		source_audio_format_is_unknown=t
	fi
	#
	#  Now we know, that the format isn’t lossess, but it is a known one.
	#  The source bitrate now should be compared to our profile tables,
	#  to determine, if it’s of a higher quality or not.
	#
	#  To compare bitrates, they should be brought to the common denomi-
	#  nator, i.e. to one number of channels. Nadeshiko always uses
	#  stereo, but the source may use 2 or 6 or 8.
	#
	[ -v src_a[channels]  ] || {
		denied 'The number of channels in the source audio track must be known,
		        but it wasn’t present in the metadata.'
		return 1
	}
	#  When the number of channels is known, check for bitrate.
	[ -v src_a[bitrate]  ] || {
		denied 'The bitrate in the source audio track must be known,
		        but it wasn’t present in the metadata.'
		return 1
	}
	#  As per https://trac.ffmpeg.org/wiki/Encode/HighQualityAudio
	source_audio_stereo_equiv_bitrate=$(
		#
		#  This calculation employs a ceiling rounding at the end,
		#  because it would be a shame to deny an encode with a better
		#  audio profile to a source, whose audio bitrate would be 191999
		#  (and not the required 192000), because one tiny bit is missing.
		#
		echo "scale=4; ch = ${src_a[channels]}/2;  \
		               br = (${src_a[bitrate]}+ch-1) / ch;  \
		      scale=0; (br+1000-1)/1000" | bc
	)
	info "Source audio track has a bitrate equivalent to two-channel ${source_audio_stereo_equiv_bitrate}k"
	#
	#  Ticket on the bullet train to all codecs: if the bitrate is higher
	#    than 503 kbps (stereo), consider that the source is audio trans-
	#    parent, i.e. worthy of encoding with a better audio bitrate.
	#  The number 503k stems from the DTS encoder, that’s said to reach
	#    transparency only at its maximum technical limit, which is 1509.75
	#    kbps for six channels, and 1509750÷(6÷2) ≈ 503250 ≈ 504 kbps
	#  This ticket is necessary to allow unknown codecs to pass this check.
	#
	if (( source_audio_stereo_equiv_bitrate > 503 )); then
		info "${source_audio_stereo_equiv_bitrate}k > 503k!  The source is probably audio transparent."
		return 0
	elif [ -v source_audio_format_is_unknown ]; then
		#  This is the last stop for the unrecognised audio formats,
		#  so there has to be a message.
		denied "Source audio track has an unknown format and its bitrate doesn’t guarantee,
		        that re-encoding it with a better audio profile will make sense."
		return 1
	fi

	#  Now to remember, which of the acodecs known to Nadeshiko the
	#  one in the source track corresponds to. The profile table
	#  of one of the known codecs hence will be used to determine,
	#  whether the bitrate in the source track reaches audio transparency
	#  or not.
	#
	local -n source_acodec_profiles=${ffmpeg_acodec}_profiles
	#
	#  And which is the default audio profile for the currently selected
	#  resolution (i.e. bitres profile)
	#
	source_acodec_default_profile=${bitres_profile[${ffmpeg_acodec}_profile]}

	#  Now to be considered “of a higher quality”, the bitrate in the
	#  source audio track has to surpass ALL audio profiles,
	#  that is above the item chosen as the default for the current
	#  bitres profile. (For each audio codec there is at least two audio
	#  profiles, that are higher, than the highest profile used in the
	#  bitres tables.) The reason why it has to be ALL profiles is explai-
	#  ned in the “Sound in Nadeshiko” article on the wiki, see the
	#  “In theory…” paragraph. https://git.io/fj8Bo
	#
	top_acodec_profile="${!source_acodec_profiles[*]}"
	top_acodec_profile=${top_acodec_profile##* }
	if (( source_audio_stereo_equiv_bitrate >= top_acodec_profile )); then
		info "Source track bitrate >= ${top_acodec_profile}k!
		      Trying a higher audio bitrate makes sense!"
	else
		denied "For $format_per_se source audio bitrate should be equal to ${top_acodec_profile}k or bigger
		        to consider switching from the default profile reasonable."
		return 1
	fi
	#
	#  Old code, may be used in the future, if comparing to lower
	#  than the topmost bitrate would be possible.
	#
	#trying_a_higher_audio_profile_makes_sense=t
	# for audio_profile in ${!source_acodec_profiles[*]}; do
	# 	(( source_audio_stereo_equiv_bitrate < audio_profile )) && {
	# 		unset trying_a_higher_audio_profile_makes_sense
	# 		break
	# 	}
	# done


	#  Keep in mind, that we’ve only counted, that the *equivalent*
	#    of the codec in the source file is of a better quality. What we
	#    are going to attempt to use is still $ffmpeg_acodec, that may
	#    or may not coincide with it.
	#  When later that $ffmpeg_acodec will be tried to fit some higher-
	#    than-the-default audio profile into the max_file_size, it may
	#    or may not fit.
	#
	return 0
}


 # Calculates, whether there is some bitrate in ${ffmpeg_acodec}_profiles
#  that would be higher than the default for the current bitres profile,
#  and would fit into the chosen file size with a padding, specific
#  to each codec.
#
do_we_have_enough_space_in_the_file() {
	declare -g  acodec_profile
	declare -g  abitrate

	local acodec_profiles_high_to_low
	local -n source_acodec_profiles=${ffmpeg_acodec}_profiles

	acodec_profiles_high_to_low=$(
		IFS=$'\n'; echo "${!source_acodec_profiles[*]}" | tac  # Sic!
	)
	old_acodec_profile=$acodec_profile

	for acodec_profile in $acodec_profiles_high_to_low; do
		abitrate=$((acodec_profile * 1000))
		recalc_acodec_size_deviation
		recalc_muxing_overhead

		if ((  (        abitrate * duration[total_s]
			          + audio_track_expected_overhead
			   )
		         <=
		       (        max_size_bits
		              - vbitrate * duration[total_s]
		              - muxing_overhead
		       )                                         ))
		then
			if (( acodec_profile > old_acodec_profile )); then
				info "${__bri}${__g}Better audio profile ${acodec_profile}k fits!${__s}"
				return 0
			else
				#  The old acodec profile was chosen
				denied 'Not enough space in the file.'
				return 1
			fi
		fi

	done
	return 1
}


try_to_fit_better_abitrate() {
	declare -g better_abitrate_set

	is_it_sensible_to_use_better_abitrate  \
		&& do_we_have_enough_space_in_the_file  \
		&& better_abitrate_set=t
	return 0
}


                   #  Main function of the module  #

 # Finds appropriate video bitrate and resolution for the encode.
#  Takes into account bitrate coefficients and constraints.
#
fit_bitrate_to_filesize() {
	declare -g  deserves_a_headpat  max_size_B  max_size_bits  vbitrate  scale
	#  As we may re-run, let’s operate on a local copy.
	local  closest_lowres_index=$closest_lowres_index  cannot_fit

	info "Calculating, how we fit… "
	milinc
	#  Do not use to_bits() here, because counting size involves
	#    the $kilo variable.
	#  max_size_B will be used later when the encoded file size
	#  would be compared to the maximum size.
	max_size_B=$max_size
	max_size_B=${max_size_B//k/*$kilo}
	max_size_B=${max_size_B//M/*$kilo*$kilo}
	max_size_B=${max_size_B//G/*$kilo*$kilo*$kilo}
	max_size_B=$(($max_size_B))
	max_size_bits=$((max_size_B*8))

	if [ -v scale ]; then
		starting_bitres_profile="$scale"
	elif [ -v closest_res ]; then
		starting_bitres_profile="$closest_res"
	else
		starting_bitres_profile="${src_v[height]}"
	fi
	current_bitres_profile="$starting_bitres_profile"
	info "Starting with ${starting_bitres_profile}p bitrate-resolution profile."
	set_bitres_profile "$starting_bitres_profile"

	recalc_space

	 # What can be done, if bitrates × duration do not fit in $max_size_bits.
	#  I find this array a genius invention, the code was a mess without it.
	#
	declare -A our_options=(
		[seek_maxfit_here]=t  #  Until vbitrate hits the minimum allowed ave-
		                      #    rage bitrate in the current bitres profile.
		[lower_resolution]=t  #  Downgrade to a lower bitrate-resolution
		                      #    profile.
	)


	 # Are we already good?
	#  If not, can we scale to lower resolutions?
	#
	until (( vbitrate <= max_fitting_vbitrate )) || [ -v cannot_fit ]; do

		unset_our_options
		#
		#  The flexibility of this code is amazing – fitting options can be
		#  stringed one on another; audio bitrate may stay fixed on some 200k
		#  while vbitrate would go round and around until the overall size
		#  fits to max_size_bits!
		#
		if [ -v our_options[seek_maxfit_here] ]; then
			if	((     max_fitting_vbitrate >= minimal_vbitrate
				    && max_fitting_vbitrate <= desired_vbitrate  ))
			then
				vbitrate=$max_fitting_vbitrate
				recalc_space
			else
				unset our_options[seek_maxfit_here]
			fi
		elif [ -v our_options[lower_resolution] ]; then
			milinc
			denied "won’t fit with ${current_bitres_profile}p."
			mildec
			#  known_res_list goes like 1080p 720p … 360p
			if (( closest_lowres_index < ${#known_res_list[@]} )); then
				current_bitres_profile=${known_res_list[closest_lowres_index]}
				echo
				#
				#  For the rare case when $overshot_times >= 1 and the increase
				#  in the muxing overhead pushed the video out of previously
				#  chosen bitrate-resolution profile. Muxing overhead must be
				#  unset, because the calculating of it was based on the old
				#  bitres profile, and for this new one it’s inapplicable. The
				#  muxing overhead shall be recalculated at least once from
				#  the base of this new profile.
				#
				(( ${overshot_times:-0} > 0 ))  \
					&& unset  muxing_overhead  filesize_antiovershoot
				set_bitres_profile $current_bitres_profile
				#  This eventually will bump the index out of array bounds
				#  essentially telling, that there is nowhere lower to go.
				let 'closest_lowres_index++,  1'
				#  New resolution – new minimal and desired bounds.
				our_options[seek_maxfit_here]=t
				recalc_space
			else
				#  Lower resolutions are depleted.
				unset our_options[lower_resolution]
			fi
		else
			denied 'No more ways to downscale.'
			cannot_fit=t
		fi
	done

	[ -v cannot_fit ] && err "Cannot fit ${duration[ts_short_no_ms]} into $max_size."

	#  This message belongs to the last bitres profile messages group.
	milinc
	info 'Fits!\n'
	mildec

	 # Detecting automatic downscale
	#  $scale is remembered and in case when an overshoot happens,
	#    $starting_bitres_profile should be assigned the bitres profile
	#    from $scale.
	#  That the video deserves a headpat must be remembered too,
	#    see the comment below.
	#
	(( current_bitres_profile != starting_bitres_profile ))  && {
		scale=$current_bitres_profile
		deserves_a_headpat=t
	}

	 # If we went a resolution down – assign better bitrate, when there is
	#    a difference between $vbitrate  and  $max_fitting_vbitrate.
	#  Earlier, there was a check on that algorithm went to downscale the
	#    resolution, but it seems, that that was superfluous, as when $vbitrate
	#    stays in the native resolution, it is automatically assigned the ma-
	#    ximum fitting bitrate – it cannot be lower. So if the $vbitrate hap-
	#    pened to be lower than $max_fitting_vbitrate, this is possible only
	#    in the case, when $vbitrate jumped over the gap between bitrate-
	#    resolution profiles, i.e. a downscale happened (otherwise $vbitrate
	#    would stay in the higher – possibly native – resolution profile).
	#  This check had a bug: it prevented the headpat from being applied
	#    on the recalculation after an overshoot, because current_bitres_profile
	#    was EQUAL to starting_bitres_profile. (After an overshoot, starting_
	#    bitres_profile is set to $scale remembered ($scale is set when going
	#    a resolution down was detected), and $scale was indeed set to the
	#    last chosen bitres profile. If downscale went say, to 360p, then
	#    $scale == 360p, $starting_bitres_profile == $scale == 360p, and
	#    it so happens, that there was no difference between the starting
	#    and current bitres profiles – no downscale jump was detected – and the
	#    headpat therefore wasn’t activated.)
	#
	local old_vbitrate_pretty  new_vbitrate_pretty
	[ -v deserves_a_headpat ] && (( vbitrate < max_fitting_vbitrate )) && {
		old_vbitrate_pretty=$(pretty "$vbitrate")
		vbitrate=$max_fitting_vbitrate
		new_vbitrate_pretty=$(pretty "$vbitrate")
		[ "$old_vbitrate_pretty" != "$new_vbitrate_pretty" ] && {
			#  Showing the info message only if the difference was big
			#  enough to be shown in “pretty” values, visible to the user.
			info "${__bri}${__g}Headpat to the poor downscaled video:
			      vbitrate=${__bri}${__w}$new_vbitrate_pretty${__s}\n"
		}
	}

	[ -v audio  -a  ! -v forced_abitrate ] && {
		info "Attempting to fit better audio."
		milinc
		#  No need to backup values: if no higher audio profile would be found,
		#  the algorithm will stop on whatever audio bitrate was previously
		#  selected.
		try_to_fit_better_abitrate
		mildec
	}

	mildrop
	echo
	return 0
}


return 0