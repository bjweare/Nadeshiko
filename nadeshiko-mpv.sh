#! /usr/bin/env bash

#  nadeshiko-mpv.sh
#  Wrapper for Nadeshiko to provide IPC with mpv.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh
#
#  mpv_crop_script.lua © TheAMM 2018
#  Licence: GPL v3,
#  see entire text in ./lib/mpv_crop_script/mpv_crop_script LICENSE


set -feEuT
shopt -s extglob
BAHELITE_CHERRYPICK_MODULES=(
	error_handling
	messages_to_desktop
	logging
	rcfile
	misc
)
mypath=$(dirname "$(realpath --logical "$0")")
case "$mypath" in
	'/usr/bin'|'/usr/local/bin')
		source "${mypath%/bin}/lib/nadeshiko/bahelite/bahelite.sh";;
	*)
		source "$mypath/lib/bahelite/bahelite.sh";;
esac
prepare_cachedir 'nadeshiko'
start_logging
set_libdir 'nadeshiko'
. "$LIBDIR/mpv_ipc.sh"
. "$LIBDIR/gather_file_info.sh"
. "$LIBDIR/time_functions.sh"
. "$LIBDIR/xml_and_python_functions.sh"
set_modulesdir 'nadeshiko'
noglob_off
for module in "$MODULESDIR"/nadeshiko-mpv_*.sh ; do
	. "$module" || err "Couldn’t source module $module."
done
noglob_on

set_metaconfdir 'nadeshiko'
set_defconfdir 'nadeshiko'
prepare_confdir 'nadeshiko'
place_examplerc 'nadeshiko-mpv.10_main.rc.sh'

declare -r version="2.4.1"
declare -gr RCFILE_REQUIRE_SCRIPT_NAME_IN_RCFILE_NAME=t

declare -r datadir="$CACHEDIR/nadeshiko-mpv_data"
#  Old, this file is deprecated.
declare -r postponed_commands="$CACHEDIR/postponed_commands"
#  New, this directory is to be used instead.
declare -r postponed_commands_dir="$CACHEDIR/postponed_commands_dir"

single_process_check



on_error() {
	local func  \
	      pyfile="$TMPDIR/nadeshiko-mpv_dialogues_gtk.py"  \
	      gladefile="$TMPDIR/nadeshiko-mpv_dialogues_gtk.glade"
	#  Wipe the data directory, so that after a stop caused by an error
	#  we wouldn’t read the old data, but tried to create new ones.
	#  The data per se probably won’t break the script, but those data
	#  could be just stale.
	touch "$datadir/wipe_me"

	for func in ${FUNCNAME[@]}; do
		#  If we couldn’t prepare option list, because we hit an error
		#  with Nadeshiko in dryrun mode…
		[ "$func" = show_dialogue_choose_preset ] && {
			[ -r "$pyfile" ] && cp "$pyfile" "$LOGDIR"
			[ -r "$gladefile" ] && cp "$gladefile" "$LOGDIR"
		}
	done

	#  Cropping module’s own on_error().
	[ "$(type -t on_croptool_error)" = 'function' ] && on_croptool_error

	return 0
}


on_exit() {
	#  If mpv still runs, clear any OSD message, that might be left hanging.
	[ -v WIPE_MPV_SCREEN_ON_EXIT  -a  -e "/proc/${mpv_pid:-not exists}" ]  \
		&& send_command  show-text  ' '  '1'
	return 0
}


show_help() {
	cat <<-EOF
	Usage:
	./nadeshiko-mpv.sh [postpone]

	    postpone – Store the command for Nadeshiko for later, instead of
	               running it right away.

	Nadeshiko-mpv in the wiki: https://git.io/fx8D6

	Post bugs here: https://github.com/deterenkelt/Nadeshiko/issues
	EOF
}


show_version() {
	cat <<-EOF
	nadeshiko-mpv.sh $version
	© deterenkelt 2018–2019.
	Licence: GNU GPL ver. 3  <http://gnu.org/licenses/gpl.html>
	This is free software: you are free to change and redistribute it.
	There is no warranty, to the extent permitted by law.
	EOF
}


post_read_rcfile() {
	local preset_name  gui_default_preset_exists
	if [ -v quick_run ]; then
		[ "${quick_run_preset:-}" ] && {
			if ! [     -r "$CONFDIR/$quick_run_preset" \
			       -a  -f "$CONFDIR/$quick_run_preset" ]
			then
				err "Quick run preset “$quick_run_preset” is not a readable file."
			fi
		}
		declare -gx postpone=t
		[ -v predictor ] && unset predictor
	else
		#  Pure default, Nadeshiko config may not exist, but this is expected.
		#  The presets in nadeshiko_presets must have file names only when
		#  there are 2+ of them.
		(( ${#nadeshiko_presets[*]} == 0 ))  \
			&& nadeshiko_presets=( [default]='nadeshiko.rc.sh' )

		if (( ${#nadeshiko_presets[*]} == 1 )); then
			gui_default_preset="${!nadeshiko_presets[@]}"
		else
			for preset_name in "${!nadeshiko_presets[@]}"; do
				[ "$gui_default_preset" = "$preset_name" ]  \
					&& gui_default_preset_exists=t
			done
			[ -v gui_default_preset_exists ]  \
				|| err "GUI default preset with name “$gui_default_preset” doesn’t exist."
		fi
	fi
	return 0
}


 # This function verifies, that all the necessary variables
#  are set at the current stage. For that it has a list of
#  variable names for each caller function.
#
check_needed_vars() {
	declare -A vars_needed=(
		[arrange_times]='time1 time2'
		[play_preview]='time1 time2 mute sub_visibility'
		[choose_preset]=''
		[encode]='time1 time2 mute sub_visibility screenshot_directory working_directory'
		[play_encoded_file]='screenshot_directory working_directory'
	)
	[ -v quick_run ] || vars_needed[encode]+=' max_size'
	for var in ${vars_needed[${FUNCNAME[1]}]}; do
		[ -v $var ] \
			|| err "Variable “$var” is not set."
	done
	return 0
}



[ -d "$datadir" ] || mkdir "$datadir"
cd "$datadir"

if [ -e wipe_me ]; then
	noglob_off
	rm -rf ./*
	noglob_on
else
	# Delete files older than one hour.
	find -type f -mmin +60  -delete
fi

set_rcfile_from_args "$@"
read_rcfile
post_read_rcfile
REQUIRED_UTILS+=(
	python3      #  Dialogue windows.
	xmlstarlet   #  To alter XML in the GUI file.
	find         #  To find and delete possible leftover data files.
	lsof         #  To check, that there is an mpv process listening to socket.
	jq           #  To parse JSON from mpv.
	socat        #  To talk to mpv via UNIX socket.
)
check_required_utils
declare -r xml='xmlstarlet'  # for lib/xml_and_python_functions.sh

builtin set -- "${NEW_ARGS[@]}"
[[ "${1:-}" =~ ^(-h|--help)$ ]] && show_help && exit 0
[[ "${1:-}" =~ ^(-v|--version)$ ]] && show_version && exit 0
[ "${1:-}"  -a  "${1:-}" = postpone ] && postpone=yes  # sic!
[ "$*" -a  "${1:-}" != 'postpone' ] && {
	show_help
	err 'The only parameter may be “postpone”!'
}
info "Nadeshiko-mpv v$version"

 # Test, that all the entries from our properties array
#  can be retrieved.
#
# retrieve_properties

 # Here is a hen and egg problem.
#  We would like to ask user to choose the socket only once, i.e. only when
#    they set Time1. On setting Time2 Nadeshiko-mpv should read $mpv_socket
#    variable from the $data_file. However, in order to find the corresponding
#    $data_file, we must know, which file is opened in mpv, where Nadeshiko-mpv
#    is called from. So we must first query mpv to read $filename, and then
#    by the $filename find a $data_file, which would have that $filename inside.
#  Thus trying to read $data_file before querying mpv is futile and will break
#    the process of setting Time1 and Time2.
#  To avoid querying mpv socket twice, Nadeshiko-mpv should process each video
#    clip in one run, not in two runs, like it is now. Nadeshiko-mpv should
#    have two windows: one before predictor runs, and one after it runs. The
#    first window would have options to connect to sockets, set times (however
#    many, 2, 4, 20…), turn on and off sound and subtitles, set crop area, and
#    run preview. The second window would  be as it is now, unchanged.
#
get_props mpv-version filename
data_file=$(grep -rlF "${filename@A}" |& head -n1)
if [ -e "$data_file" ]; then
	# Read properties.
	. "$data_file"
else
	 # Check connection and get us filename to serve as an ID for the playing
	#    file, as for getting path we’d need working-directory. Not taking
	#    path for ID to not do the job twice.
	#
	data_file=$(mktemp --tmpdir='.'  mpvfile.XXXX)
	# printf "filename=%q\n" "$filename" > "$data_file"
	write_var_to_datafile filename "$filename"
	write_var_to_datafile mpv_socket "$mpv_socket"
fi


 # Must be here, because mpv_pid is used in functions, that send messages
#  to mpv window, when it may be closed. To avoid that, we must know
#  its PID and check if it’s still running, so if there would be
#  no window, we wouldn’t send anything.
#
export mpv_pid=$(lsof -t -c mpv -a -f -- "$mpv_socket")
[[ "$mpv_pid" =~ ^[0-9]+$ ]] || err "Couldn’t determine mpv PID."


#  If this is the first run, set time1 and quit.
#  On the second run (time2 is set) do the rest.
put_time && [ -v time2 ] && {
	#  Check, if Time1 and Time2 are the same and order them properly.
	arrange_times
	choose_crop_settings
	play_preview
	if [ -v quick_run ]; then
		[ "$quick_run_preset" ] && nadeshiko_preset=$quick_run_preset
	else
		choose_preset
	fi
	#  Prepares the encoding
	#  - if “postpone” is enabled, saves the job and calls exit
	#  - if “postpone” is disabled, runs encoder, then returns
	#    to play encoded file.
	encode
	#  Show the encoded file.
	play_encoded_file
}


exit 0