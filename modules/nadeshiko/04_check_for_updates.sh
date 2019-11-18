#  Should be sourced.

#  04_check_for_updates.sh
#  Nadeshiko module to query the “Latest release” page on Github and display
#  a notification, if a new version is available.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh


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