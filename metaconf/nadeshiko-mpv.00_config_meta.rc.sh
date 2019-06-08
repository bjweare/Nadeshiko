#  nadeshiko-mpv.00_config_meta.rc.sh
#
#  This initial piece of configuration predefines types for regular and
#  associative arrays. This allows to keep the actual definitions minimal
#  for the end users – who might forget to copy the definitions to their
#  config files or type -a instead of -A.



declare -gA mpv_sockets
declare -gA nadeshiko_presets


 # Pseudo-boolean variables, that the main script will check for yes/no
#  on/off, true/false, 1/0 and either leaves or unsets – making their
#  existence into a boolean value.
#
RCFILE_BOOLEAN_VARS=(
	show_preview
	show_encoded_file
	predictor
	postpone
	quick_run
)
