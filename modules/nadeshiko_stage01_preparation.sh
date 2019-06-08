#  Should be sourced.

#  nadeshiko_stage01_preparation.sh
#  Nadeshiko module containing preparation stage functions.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh


compose_known_res_list() {
	local i j swap bitres_profile
	for bitres_profile in ${!bitres_profile_*}; do
		[[ "$bitres_profile" =~ ^bitres_profile_([0-9]+)p$ ]]  \
			&& known_res_list+=( ${BASH_REMATCH[1]} )
	done
	for ((i=0; i<${#known_res_list[@]}-1; i++)); do
		for ((j=i+1; j<${#known_res_list[@]}; j++)); do
			[ ${known_res_list[j]} -gt ${known_res_list[i]} ] && {
				swap=${known_res_list[i]}
				known_res_list[i]=${known_res_list[j]}
				known_res_list[j]=$swap
			}
		done
	done
	return 0
}


post_read_rcfile() {
	declare -g  muxing_sets  codec_name_as_formats  container_own_size_pct  \
	            minimal_bitrate_pct  rc_default_subs  rc_default_audio  \
	            scale  rc_default_scale
	local  pct_varname  pct_var  vcodec

	#  Setting up the superglobal variables for Bahelite.
	[ -v new_release_check_interval ]  \
		&& declare -g GITHUB_NEW_RELEASE_CHECK_INTERVAL="$new_release_check_interval"
	[ -v desktop_notifications ] && {
		#  Enabling it as early as possible, or the errors about wrong argu-
		#  ments won’t have desktop notifications.
		. "$LIBDIR/bahelite/bahelite_messages_to_desktop.sh"
		check_required_utils
	}

	#  Processing the rest of the variables
	[[ "$max_size_default" =~ ^(tiny|small|normal|unlimited)$ ]]  \
		&& declare -gn max_size_default=max_size_${max_size_default}  \
		|| err 'Invalid value for max_size_default.'

	vcodec=${ffmpeg_vcodec//-/_}
	declare -gn codec_name_as_formats=${vcodec}_codec_name_as_formats
	declare -gn muxing_sets=${vcodec}_muxing_sets
	declare -gn container_own_size_pct=${vcodec}_container_own_size_pct
	declare -gn minimal_bitrate_pct=${vcodec}_minimal_bitrate_pct
	(
		   [[ "$minimal_bitrate_pct" =~ ^[0-9]{1,3}$ ]]  \
		&& (( minimal_bitrate_pct > 0  &&  minimal_bitrate_pct <= 100 ))
	) \
		|| err "${vcodec}_minimal_bitrate_pct must be a number between in range 0…100."

	compose_known_res_list

	#  Let the defaults for these parameters be determined by the user.
	[ -v subs ] && rc_default_subs=t
	[ -v audio ] && rc_default_audio=t
	#  NB “scale” from RC doesn’t set force_scale!
	[ -v scale ] && scale=${scale%p}  rc_default_scale=$scale
	# [ -v time_stat ] && ffmpeg_input_options+=( -benchmark )  # test later
	return 0
}


check_for_new_release_on_github() {
	[[ "$GITHUB_NEW_RELEASE_CHECK_INTERVAL" =~ ^[0-9]{1,4}$ ]]  \
		|| err "Invalid updates checking interval in the RC file:
		        “$GITHUB_NEW_RELEASE_CHECK_INTERVAL”."
	check_for_new_release  deterenkelt  \
	                       Nadeshiko  \
	                       $version  \
	                       "$release_notes_url"  \
		|| true
	return 0
}


return 0