#! /usr/bin/env bash

#  mpv_ipc.sh
#  Implementation of a library, that reads and sets mpv properties (only
#  a limited number of them), can verify values and assign to variables.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh


 # THIS IS A LOW-LEVEL LIBRARY with some requirements to the main script.
#  A script on the higher level must do:
#  - strict error checking (set -feEu and -o pipefail possibly);
#  - logging;
#  - source bahelite.sh for err(), other functions and properly handled
#    exits from subshell.


 # Known mpv properties (that tests are implemented for)
#  Functions use this array for two things:
#  - to confirm, that the property name exists,
#    i.e. that there’s no mistake in the name;
#  - to validate the values retrieved from mpv.
#
declare -r -A properties=(
	#  The syntax is:
	#  [property_name]="good_value_test  bad_value_test"
	#                                  ^^
	#                    space separated (however many)
	#
	#  “Good value” test and “Bad value” test are eval’ed, and whichever
	#  of them passes first, assigns the value to <property_name>.
	#  If neither of them passes, <property_name> is considered failed
	#  to retrieve and the program gets aborted.
	#
	#  If “Good value” test passes, then a new variable set with a name like
	#  “<property_name>_true”. For boolean properties (yes/no, on/off, 0/1)
	#  checking on the existence of *_true variable provides an universal way
	#  to determine, whether the property has true/1/on/yes… thus leaving all
	#  the differences on the retrieving stage. For non-boolean variables
	#  absence of this *_true variable would mean, that it has no value, e.g.
	#  when it may have a path, but mpv returned an empty string (still okay).
	#
	#  There are properties, that return not a boolean value, but a path for
	#  example. Or a file name. Such properties should use a test for a non-
	#  empty string as “good value” test or a check for file existence.
	#  Killing two  hares with one stone.
	#
	#  Mpv also has properties, which may have no value – neither boolean,
	#  nor a string at all. Nevertheless an empty value for them is normal
	#  and shouldn’t trigger program exit. For these put simple command “true”
	#  as “Bad value” test.

	#  To test connection.
	[mpv-version]='test_mpv_version  false'

	#  File name, that mpv is playing.
	#  Serves as an ID string in the data file, so just a nonempty string.
	[filename]='test_nonempty_string  false'

	#  Full path to that file.
	#  May be relative, so needs a check on working-directory to be useful.
	[path]='test_file_exists  false'

	#  Title from metadata.
	[media-title]='test_nonempty_string  true'  # <— May be unset

	#  If paused.
	[pause]='test_yes_true_on  test_no_false_off'

	#  Current time.
	[time-pos]='test_time_pos  false'

	#  OS volume
	# [ao-volume]='[[ "$propval" =~ .* ]]'$'\n'

	#  OS mute
	# [ao-mute]='[[ "$propval" =~ .* ]]'$'\n'  # may be unimplemented

	#  Video size as integers, with no aspect correction applied.
	# [video-params/w]
	# [video-params/h]

	#  Video size as integers, scaled for correct aspect ratio.
	# [video-params/dw]
	# [video-params/dh]

	#  Video aspect ratio.
	# [video-params/aspect]

	#  If window is minimised.
	# [window-minimized]='[[ "$propval" =~ .* ]]'$'\n'

	#  Audio track ID
	# [aid]

	#  Subtitle track ID
	# [sid]

	#  If muted
	[mute]='test_yes_true_on  test_no_false_off'

	#  Sound volume
	[volume]='test_number false'

	#  Current line in subtitles, that’s being displayed.
	# [sub-text]=

	#  Path where mpv seeks for subtitles.
	# [sub-file-paths]='[[ "$propval" =~ .* ]]'$'\n'

	#  Are subtitles shown or hidden.
	[sub-visibility]='test_yes_true_on  test_no_false_off'

	#  If mpv is in fullscreen mode.
	[fullscreen]='test_yes_true_on  test_no_false_off'

	#  Don’t close until…(?).
	# [keep-open]=

	#  mpv’s screenshot directory.
	[screenshot-directory]='test_dir_exists  true'  # <— May be unset

	#  mpv’s current working directory.
	[working-directory]='test_dir_exists  false'

	#  It can only be set.
	[show-text]='test_nonempty_string  true'  # <— May be unset

	#  Window geometry W:H:X:Y.
	# [geometry]=

	#  Is WM border on or off.
	# [no-border]=

	#  Is mpv window above all other windows?
	# [ontop]=

	#  List of video, audio and subtitle tracks.
	#  The contents is JSON array with data for each track.
	[track-list]='test_nonempty_string  false'
	#  Total number of tracks in the list.
	[track-list/count]='test_number  false'

	#  Hide cursor over the window
	[cursor-autohide]='test_cursor_autohide_true  test_cursor_autohide_false'

	#  Hide cursor over the window
	[cursor-autohide-fs-only]='test_yes_true_on  test_no_false_off'

	#  Set an option locally, i.e. for the current file only.
	# file-local-options/<name>

	#  Request choices
	# option-info/<name>/choices
)

test_nonempty_string() {
	[ "$1" ]
}
test_number() {
	[[ "$1" =~ ^[0-9]+$ ]]
}
test_float() {
	[[ "$1" =~ ^[0-9]+\.[0-9]+$ ]]
}
test_file_exists() {
	local arg exists
	[ -v working_directory ] || err 'Working directory must be set!'
	for arg in "$@"; do
		[ -f "$arg" -o -f "$working_directory/$arg" ] && exists=t && break
	done
	[ -v exists ]
}
test_dir_exists() {
	[ -d "$1" ]
}
test_yes_true_on(){
	[[ "$1" =~ ^(y|Y|[Yy]es|1|t|T|[Tt]rue|[Oo]n|[Ee]nable[d])$ ]]
}
test_no_false_off(){
	[[ "$1" =~ ^(n|N|[Nn]o|0|f|F|[Ff]alse|[Oo]ff|[Dd]isable[d])$ ]]
}
test_mpv_version() {
	[[ "$1" =~ ^mpv\ .*$ ]]
}
test_time_pos() {
	[[ "$1" =~ ^[0-9]+\.[0-9]{1,6}$ ]]
}
test_cursor_autohide_true() {
	[[ "$1" =~ ^always$  || "$1" =~ ^[0-9]{1,5}$ ]]
}
test_cursor_autohide_false() {
	[[ "$1" =~ ^no$ ]]
}


 # Choose a socket from predefined in the associative array mpv_sockets.
#
#  MUST BE CALLED BY ITSELF IN THE MAIN SHELL CONTEXT, SOMEWHERE IN THE
#  BEGINNING.
#
#  Entries of mpv_sockets have format [human_readable_name]="/path/to/socket".
#  - what socket an mpv instance should use is defined by either command line
#    option “--input-ipc-server”, or the option in the config file.
#  - mpv instances may differ by the socket they use,
#    say, SMplayer to watch movies vs standalone mpv to watch downloaded
#    videos from youtube;
#  - several mpv instances may use the same socket – all but one must be
#    closed, otherwise working with it will eventually lead to errors after
#    2–3 reads;
#  - if Nadeshiko-mpv sees one mpv listening to socket A and one mpv
#    listening to socket B, a dialogue window spawns to choose socket.
#
check_socket() {
	local i

	#  Avoid recursive processing.
	for ((i=1; i<${#FUNCNAME[@]}; i++)); do
		[ "${FUNCNAME[i]}" = check_socket ] && return 0
	done

	debug51-info 'Checking mpv socket'
	milinc

	declare -gx mpv_socket  #  Sic! After the possible early return!

	local  sockets_that_work=()
	local  socket_name
	local  socket_path
	local  sockets_occupied=()
	local  sockets_unused=()
	local  bad_sockets=()
	local  dialog_socket_list=()
	local  err_message
	local  resp_mpv_socket

	(( ${#mpv_sockets[@]} == 0 ))  && err 'No sockets defined.'

	 # To avoid get_prop annoying the user with “Choose a socket” 50 times
	#  during the same run, limit the socket list to already chosen socket
	#  and just check, that it’s still there and okay.
	#
	[ -v mpv_socket ] && mpv_sockets=( [Already_chosen]="$mpv_socket" )
	for socket_name in ${!mpv_sockets[@]}; do
		socket_path=${mpv_sockets[$socket_name]}
		debug51-info "Socket [$socket_name]=\"$socket_path\""
		milinc
		if [ -S "$socket_path" ]; then
			debug51-msg 'Path leads to a proper socket file.'
			 # In the future, it may be necessary to use
			#  lsof -t +E -- "$socket_path"
			#
			if lsof_output=$(lsof -t -c mpv -a -f -- "$socket_path"); then
				debug51-msg 'Socket is used by mpv(s?).'

				 # This override is for the weird behaviour, when mpv spawns
				#  a subprocess after “load-script” command. (The next command
				#  sent in a row with “load-script”, e.g. “script-binding”,
				#  would fail occasionally, because it would see that phantom
				#  mpv process spawned by the previous command, which would
				#  occupy the socket. This mpv subprocess doesn’t break IPC,
				#  so the only way is to ignore it.)
				#
				if [ -v MPV_IPC_CHECK_SOCKET_ASSUME_ONE_PROCESS ]; then
					debug51-info 'Assuming there is only one mpv process to avoid a bug.'
					sockets_that_work+=( "$socket_name" )
				else
					case "$(wc -l <<<"$lsof_output")" in
						1)
							debug51-info 'Only one mpv process uses this socket.'
							sockets_that_work+=( "$socket_name" )
							;;
						*)
							debug51-warn "Several mpv use this socket:
							              $lsof_output"
							sockets_occupied+=( "$socket_path" )
							;;
					esac
				fi
			else
				sockets_unused+=("$socket_path")
				debug51-info "No mpv is listening this socket."
			fi
		else
			bad_sockets+=("$socket_path")
			if [ -e "$socket_path" ]; then
				if [ -r "$socket_path" ]; then
					debug51-warn "File exists, but isn’t a socket."
				else
					debug51-warn "Path doesn’t lead to a readeable file."
				fi
			else
				debug51-warn "Path doesn’t exist."
			fi
		fi
		mildec
	done

	case "${#sockets_that_work[@]}" in
		0)
			err_message="Socket error: "
			(( ${#sockets_occupied[@]} != 0 ))  \
				&& err_message+=$'\n'"${#sockets_occupied[@]} socket(s) occupied."
			(( ${#sockets_unused[@]} != 0 ))  \
				&& err_message+=$'\n'"${#sockets_unused[@]} socket(s) unused."
			(( ${#bad_sockets[@]} != 0 ))  \
				&& err_message+=$'\n'"${#bad_sockets[@]} bad socket(s)."
			err "$err_message"
			;;
		1)
			mpv_socket=${mpv_sockets[$sockets_that_work]}
			;;
		*)
			for ((i=0; i<${#sockets_that_work[@]}; i++)); do
				#  String to return in stdout
				dialog_socket_list+=($i)
				#  String to display in the radiobox label
				dialog_socket_list+=("${sockets_that_work[i]}")
				#  Which radiobox should be active
				(( i == 0 ))  \
					&& dialog_socket_list+=( on  )  \
					|| dialog_socket_list+=( off )

				 # In order to bring the dialogue window in front, the mpv
				#  window has to be unmaximised. But since it is not known
				#  at this time yet, which mpv socket we should work with,
				#  each window has to be set on pause and unmaximised. At
				#  least this is better than when a user presses a hotkey
				#  and nothing visibly happens.
				#
				mpv_socket="${mpv_sockets[${sockets_that_work[i]}]}"  #  Temporarily!
				set_prop 'pause' 'yes'
				set_prop 'fullscreen' 'no'

			done

			#  Returning $mpv_socket to undefined state.
			unset mpv_socket
			declare -gx mpv_socket  #  Because unset has reset the flags.
			show_dialogue_choose_mpv_socket 'dialog_socket_list'
			resp_mpv_socket="$dialog_output"
			[[ "$resp_mpv_socket" =~ ^[0-9]+$ ]] \
			&& (( resp_mpv_socket >= 0  )) \
			&& (( resp_mpv_socket <= ${#sockets_that_work[@]} )) \
				|| err 'Dialog returned invalid socket index.'
			#  mpv_socket is now an array index (integer),
			#  we use it for sockets_that_work, that has names like “Usual”.
			mpv_socket=${sockets_that_work[resp_mpv_socket]}
			#  Now we dereferense that human name into file name by the
			#  list specified in rc.sh.
			mpv_socket=${mpv_sockets[$mpv_socket]}
			;;
	esac
	mildec
	return 0
}


check_prop_name() {
	local  propname_to_test="$1"
	local  found

	for propname in ${!properties[@]}; do
		[ "$propname" = "$propname_to_test" ] && found=t && break
	done
	[ -v found ] || err "mpv-ipc module doesn’t have this property: “$propname_to_test”."

	return 0
}


send_command() {
	local  command="$1"
	local  command_args
	local  mpv_answer
	local  data
	local  status
	local  return_data_via_stdout

	[ "${FUNCNAME[1]}" = 'get_prop' ] && return_data_via_stdout=t
	unset data
	shift
	check_socket
	for arg in "$@"; do
		command_args+=", \"$arg\""
	done
	debug52-info "$FUNCNAME: sending a command to mpv via IPC:
	              command: $command
	              arguments: $@"
	#  Would be good to implement check on request id – any string that
	#  should be returned as it was passed.
	#
	#  { "command": ["get_property", "time-pos"], "request_id": 100 }
	#  { "error": "success", "data": 1.468135, "request_id": 100 }
	mpv_answer=$(
		#  Sleep for consecutive runs.
		#  mpv devs use timeout 300 ms, but it seems, that Nadeshiko-mpv
		#  works fine just like that. A lag of 0.3 several times in a row
		#  is noticeable while setting Time1.
		#  sleep .3
		cat <<-EOF | socat - "$mpv_socket"
		{ "command": ["$command"${command_args:-}] }
		EOF
	) || err "Connection refused."

	# command:
	# {"data":null,"error":"success"}
	# {"error":"invalid parameter"}
	#
	# get_property_string:
	# {"data":"326.994000","error":"success"}
	# {"data":"no","error":"success"}
	# {"data":null,"error":"success"}  # NB properties that may only be set,
	#                                  # return not a string, but null!
	#
	# set_property:
	# {"error":"success"}
	# {"error":"property not found"}
	#
	#  There may be no .data, it’s OK, and it returns OK.

	data=$(echo "$mpv_answer" | jq -r .data 2>&1) || {
		redmsg "“$command $*”: no .data in JSON answer. The answer was:
		        $mpv_answer"
		err "Protocol error"
	}
	status=$(echo "$mpv_answer" | jq -r .error 2>&1) || {
		redmsg "“$command $*”: no .error in JSON answer. The answer was:
		        $mpv_answer"
		err "Protocol error"
	}

	#  If there’s no status, or status ≠ success, this is a problem.
	[ "$status" != success ] && {
		redmsg "$command $*: the status in the error field is “$status”."
		err "Protocol error"
	}

	[ -v return_data_via_stdout ] && echo "$data"
	return 0
}


internal_set_prop() {
	local  propname="$1"
	local  propval="$2"
	local  orig_propname
	local  prop_true_test
	local  prop_false_test

	read -d '' prop_true_test prop_false_test  \
		< <( echo -n "${properties[$propname]}"; echo -en '\0' )
	orig_propname=$propname
	propname=${propname//-/_}
	propname=${propname//\//_}
	unset $propname  ${propname}_true
	if $prop_true_test "$propval"; then
		declare -g $propname="$propval"
		declare -g ${propname}_true=t
		return 0
	elif $prop_false_test "$propval"; then
		declare -g $propname="$propval"
		return 0
	else
		#  Undefined
		unset $propname
		redmsg "$FUNCNAME: Unknown value for $orig_propname: “$propval”."
		err "MPV-IPC: property value type mismatch."
	fi

	return 0
}


get_prop() {
	local  propname="$1"
	local  propdata

	check_prop_name "$propname"
	 # "get_property" vs "get_property_string"
	#    The latter gives more predictable and universal results. The downside
	#    is that checking the error field in the mpv reponse becomes futile:
	#    it will always return “success” even for unexisting variables.
	#    “null” for data isn’t a sign of an error, the variable might just be
	#    not set neither in config, nor in command line.
	#  exit $? here is important, because without it in case of “connection
	#    refused” error there would be two error messages: one for the error
	#    triggered within send_command() – the actual error. And the bash
	#    error on the line below: since send_command() runs in a subshell,
	#    err function couldn’t really exit.
	propdata=$(send_command 'get_property_string' "$propname")
	[ "$propdata" = null ] && propdata=''
	#  https://github.com/deterenkelt/Nadeshiko/issues/1
	[ "$propname" = 'screenshot-directory'  -a  "$propdata" = '~~desktop/' ] \
		&& propdata=''
	[ "$propname" = 'volume' ] && propdata=${propdata%.*}
	internal_set_prop "$propname" "$propdata"

	return 0
}


get_props() {
	local propname
	for propname in "$@"; do
		get_prop "$propname"
	done
	return 0
}


set_prop() {
	local  propname="$1"
	local  propval="$2"
	local  mpv_answer status

	check_prop_name "$propname"
	send_command 'set_property' "$propname" "$propval"
	# a Check the answer here.

	return 0
}


 # Analogue of get_props(), but for testing purposes.
#  Prints in a table form all retrievable (that is, known to mpv_ipc.sh)
#  properties, their values and if_true status to console.
#
retrieve_properties() {
	local  propname
	local  propval
	local  propval_if_true orig_propname

	for propname in ${!properties[@]}; do
		get_prop "$propname"
		orig_propname=$propname
		propname=${propname//-/_}
		propname=${propname//\//_}
		declare -n propval=$propname
		declare -n propval_if_true=${propname}_true
		echo -e "$orig_propname\t$propval\t${propval_if_true:-f}"
	done | column -t -s $'\t'

	return 0
}


return 0