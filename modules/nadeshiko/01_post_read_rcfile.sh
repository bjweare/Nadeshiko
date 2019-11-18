#  Should be sourced.

#  01_post_read_rcfile.sh
#  Nadeshiko module to process the variables read from the meta, default
#  and user’s RC file(s).
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh



compose_known_res_list() {
	declare -g  known_res_list

	local  bitres_profile
	local  swap
	local  i
	local  j

	for bitres_profile in ${!bitres_profile_*}; do
		[[ "$bitres_profile" =~ ^bitres_profile_([0-9]+)p$ ]]  \
			&& known_res_list+=( ${BASH_REMATCH[1]} )
	done
	for ((i=0; i<${#known_res_list[*]}-1; i++)); do
		for ((j=i+1; j<${#known_res_list[*]}; j++)); do
			(( ${known_res_list[j]} > ${known_res_list[i]} )) && {
				swap=${known_res_list[i]}
				known_res_list[i]=${known_res_list[j]}
				known_res_list[j]=$swap
			}
		done
	done
	return 0
}


post_read_rcfile() {
	declare -g  muxing_sets
	declare -g  codec_name_as_formats
	declare -g  minimal_bitrate_pct
	declare -g  rc_default_subs
	declare -g  rc_default_audio
	declare -g  scale
	declare -g  rc_default_scale
	declare -g  custom_output_framerate_set
	declare -g  known_res_list=()

	local  pct_varname
	local  pct_var
	local  vcodec=${ffmpeg_vcodec//-/_}
	local  varname
	local  i

	#  Setting up the superglobal variables for Bahelite.
	[ -v new_release_check_interval ]  \
		&& declare -g GITHUB_NEW_RELEASE_CHECK_INTERVAL="$new_release_check_interval"
	[ -v desktop_notifications ] && {
		#  Enabling it as early as possible, or the errors about wrong argu-
		#  ments won’t have desktop notifications.
		bahelite_load_module 'messages_to_desktop'
		check_required_utils
	}

	#  Processing the rest of the variables
	declare -gn max_size_default=max_size_${max_size_default}
	declare -gn codec_name_as_formats=${vcodec}_codec_name_as_formats
	declare -gn muxing_sets=${vcodec}_muxing_sets
	declare -gn minimal_bitrate_pct=${vcodec}_minimal_bitrate_pct

	compose_known_res_list

	#  Let the defaults for these parameters be determined by the user.
	[ -v subs ] && rc_default_subs=t
	[ -v audio ] && rc_default_audio=t
	#  NB “scale” from RC doesn’t set force_scale!
	if [ "${scale:-}" = no ]; then
		unset scale
	else
		scale="${scale%p}"
		rc_default_scale=$scale
	fi
	# [ -v time_stat ] && ffmpeg_input_options+=( -benchmark )  # test later

	for varname in ${vcodec}_pass1_extra_options  \
	               ${vcodec}_pass2_extra_options
	do
		local -n pass_params=$varname
		for ((i=0; i<${#pass_params[*]}; i++)); do
			[ "${pass_params[i]}" = '-r' ] && {
				custom_output_framerate=${pass_params[i+1]}
				[[ "$custom_output_framerate" =~ ^[0-9]+(/[0-9]+|\.[0-9]+|)$ ]]  \
					|| err "Unknown output frame rate value set in $varname: “$custom_output_framerate”."
				break 2
			}
		done
	done

	return 0
}


return 0