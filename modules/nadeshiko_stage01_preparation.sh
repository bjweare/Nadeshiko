#  Should be sourced.

#  stage01_preparation.sh
#  Nadeshiko module containing preparation stage functions.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh


compose_known_res_list() {
	local i j swap bitres_profile
	for bitres_profile in ${!bitres_profile_*}; do
		[[ "$bitres_profile" =~ ^bitres_profile_([0-9]+)p$ ]] \
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
	local  pct_varname  pct_var

	#  Setting up the superglobal variables for Bahelite.
	[ -v new_release_check_interval ] \
		&& declare -g NEW_RELEASE_CHECK_INTERVAL="$new_release_check_interval"
	[ -v desktop_notifications ] \
		|| declare -g NO_DESKTOP_NOTIFICATIONS=t

	#  Processing the rest of the variables
	[[ "$max_size_default" =~ ^(tiny|small|normal|unlimited)$ ]] \
		&& declare -gn max_size_default=max_size_${max_size_default} \
		|| err 'Invalid value for max_size_default.'
	for pct_varname in $(compgen -A variable | grep '_pct$'); do
		declare -n pct_var=$pct_varname
		pct_var=${pct_var%\%}
	done

	compose_known_res_list

	#  Let the defaults for these parameters be determined by the user.
	[ -v subs ] && rc_default_subs=t
	[ -v audio ] && rc_default_audio=t
	#  NB “scale” from RC doesn’t set force_scale!
	[ -v scale ] && scale=${scale%p}  rc_default_scale=$scale

	return 0
}


check_for_new_release_on_github() {
	[[ "$NEW_RELEASE_CHECK_INTERVAL" =~ ^[0-9]{1,4}$ ]] \
		|| err "Invalid updates checking interval in the RC file:
		        “$NEW_RELEASE_CHECK_INTERVAL”."
	check_for_new_release  deterenkelt Nadeshiko $version \
	                       "$release_notes_url" ||:
	return 0
}


return 0