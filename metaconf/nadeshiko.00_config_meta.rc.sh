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
RCFILE_CHECKVALUE_VARS+=(
	[check_for_updates]='bool'
	[new_release_check_interval]='int_in_range 1 365'
	[desktop_notifications]='bool'
	[max_size_normal]='int_in_range_with_unit 1 99999 [kMG]'
	[max_size_small]='int_in_range_with_unit 1 99999 [kMG]'
	[max_size_tiny]='int_in_range_with_unit 1 99999 [kMG]'
	[max_size_unlimited]='int_in_range_with_unit 1 99999 [kMG]$'
	[max_size_default]='^(tiny|small|normal|unlimited)$'
	[kilo]='^(1000|1024)$'
	[pedantic]='bool'
	[time_stat]='bool'
	[create_windows_friendly_filenames]='bool'
	[subs]='bool'
	[audio]='bool'
	[ffmpeg_progressbar]='bool'
	[scale]='^((2160|1440|1080|720|576|480|360)p|no)$'
	[video_sps_threshold]='float'
	[crop_uses_profile_vbitrate]='bool'
	[min_esp_unit]='int_in_range_with_unit 1 99999 [kMG]'
)