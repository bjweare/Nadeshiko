#  nadeshiko.00_config_meta.rc.sh
#
#  This initial piece of configuration predefines types for regular and
#  associative arrays. This allows to keep the actual definitions minimal
#  for the end users – who might forget to copy the definitions to their
#  config files or type -a instead of -A.



declare -gA  ffmpeg_muxers
declare -gA  bitres_profile_360p
declare -gA  bitres_profile_480p
declare -gA  bitres_profile_576p
declare -gA  bitres_profile_720p
declare -gA  bitres_profile_1080p
declare -gA  bitres_profile_1440p
declare -gA  bitres_profile_2160p
declare -gA  ffmpeg_subtitle_fallback_style


 # Pseudo-boolean variables, that the main script will check for yes/no
#  on/off, true/false, 1/0 and either leaves or unsets – making their
#  existence into a boolean value.
#
RCFILE_BOOLEAN_VARS=(
	desktop_notifications
	check_for_updates
	subs
	audio
	scale
	pedantic
	time_stat
	crop_uses_profile_vbitrate
	create_windows_friendly_filenames
)
