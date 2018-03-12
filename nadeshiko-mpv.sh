#! /usr/bin/env bash

# nadeshiko-mpv.sh
#   Wrapper for Nadeshiko to provide IPC with mpv.
#   deterenkelt © 2018

# This program is free software; you can redistribute it and/or modify it
#   under the terms of the GNU General Public License as published
#   by the Free Software Foundation; either version 3 of the License,
#   or (at your option) any later version.
# This program is distributed in the hope that it will be useful,
#   but without any warranty; without even the implied warranty
#   of merchantability or fitness for a particular purpose.
#   See the GNU General Public License for more details.

set -feEu
declare -r BHLLS_LOGGING_ON=t
. "$(dirname "$0")/bhlls.sh"
declare -r MY_MSG_TITLE='Nadeshiko-mpv'
required_utils+=(
	Xdialog  # To show a confirmation window that also sets max. file size.
)
check_required_utils


declare -r rc_file="$MYDIR/nadeshiko-mpv.rc.sh"
declare -r example_rc_file="$MYDIR/example.nadeshiko-mpv.rc.sh"
declare -r version="20180312"

 # Reading the RC file.
#
if [ -r "$rc_file" ]; then
	. "$rc_file"
else
	if [ -r "$example_rc_file" ]; then
		cp "$example_rc_file" "$rc_file" || err "Couldn’t create RC file!"
		. "$rc_file"
	else
		err "No RC file or example RC file was found!"
	fi
fi

declare -r datadir="$MYDIR/nadeshiko-mpv_data"
[ -d "$datadir" ] || mkdir "$datadir"
cd "$datadir"
# Delete files older than one hour.
find -type f -mmin +60 -delete

 # mpv properties
#  Functions use this array for two things:
#  - to confirm, that the property name exists,
#    i.e. that there’s no mistake in the name;
#  - to validate the values retrieved from mpv.
#
declare -A properties=(
	# The syntax is:
	# [property_name]="good_value_test"$'\n'"bad_value_test"
	#                                    ^^------------------newline separates
	#
	# “Good value” test and “Bad value” test are eval’ed, and whichever
	# of them passes first, assigns the value to <property_name>.
	# If neither of them passes, <property_name> is considered failed
	# to retrieve and the program gets aborted.
	#
	# If “Good value” test passes, then a new variable set with a name like
	# “<property_name>_true”. For boolean properties (yes/no, on/off, 0/1)
	# checking on the existence of *_true variable provides an universal way
	# to determine, whether the property has true/1/on/yes… thus leaving all
	# the differences on the retrieving stage. For non-boolean variables
	# absence of this *_true variable would mean, that it has no value, e.g.
	# when it may have a path, but mpv returned an empty string (still okay).
	#
	# There are properties, that return not a boolean value, but a path for
	# example. Or a file name. Such properties should use a test for non-empty
	# string as “good value” test or a check for file existence. Killing two
	# hares with one shot.
	#
	# Mpv also has properties, which may have no value – neither boolean,
	# nor a string at all. Nevertheless an empty value for them is normal and
	# shouldn’t trigger program exit. For these put simple command “true”
	# as “Bad value” test.

	# To test connection.
	[mpv-version]='[[ "$propval" =~ ^mpv\\ .*$ ]]'$'\n'

	# File name, that mpv is playing.
	[filename]='[[ "$propval" =~ .+ ]]'$'\n'

	# Full path to that file.
	[path]='[ -e "$propval" ]'$'\n'

	# Title from metadata.
	[media-title]='[[ "$propval" =~ .+ ]]'$'\n''true'  # <— May be unset

	# Current time.
	[time-pos]='[[ "$propval" =~ ^[0-9]+.[0-9]{6}$ ]]'$'\n'

	# OS volume
	# [ao-volume]='[[ "$propval" =~ .* ]]'$'\n'

	# OS mute
	# [ao-mute]='[[ "$propval" =~ .* ]]'$'\n'  # may be unimplemented

	# Video size as integers, with no aspect correction applied.
	# [video-params/w]
	# [video-params/h]

	# Video size as integers, scaled for correct aspect ratio.
	# [video-params/dw]
	# [video-params/dh]

	# Video aspect ratio.
	# [video-params/aspect]

	# If window is minimised.
	# [window-minimized]='[[ "$propval" =~ .* ]]'$'\n'

	# Audio track ID
	# [aid]

	# Subtitle track ID
	# [sid]

	# If muted
	[mute]='[ "$propval" = yes ]'$'\n''[ "$propval" = no ]'

	# Current line in subtitles, that’s being displayed.
	# [sub-text]=

	# Path where mpv seeks for subtitles.
	# [sub-file-paths]='[[ "$propval" =~ .* ]]'$'\n'

	# Are subtitles shown or hidden.
	[sub-visibility]='[ "$propval" = yes ]'$'\n''[ "$propval" = no ]'

	# If mpv is in fullscreen mode.
	[fullscreen]='[ "$propval" = yes ]'$'\n''[ "$propval" = no ]'

	# Don’t close until…(?).
	# [keep-open]=

	# mpv’s screenshot directory.
	[screenshot-directory]='[ -d "$propval" ]'$'\n''true'  # <— May be unset

	# mpv’s current working directory.
	[working-directory]='[ -d "$propval" ]'$'\n'

	# It can only be set.
	[show-text]='[[ "$propval" =~ .+ ]]'$'\n''true'  # <— May be unset

	# Window geometry W:H:X:Y.
	# [geometry]=

	# Is WM border on or off.
	# [no-border]=

	# Is mpv window above all other windows?
	# [ontop]=

	# Set an option locally, i.e. for the current file only.
	# file-local-options/<name>

	# Request choices
	# option-info/<name>/choices
)

show_help() {
	cat <<-EOF
	Usage:
	./nadeshiko-mpv.sh

	This program automatically connects to mpv socket (set the path to it
	in $rc_file). On the first run it sets Time1, on the second run –
	Time2 and goes further to preview, encode and post-preview.

	This script should be bound to a hotkey in the window manager,
	mpv itself doesn’t send any commands to it.
	EOF
}

show_version() {
	cat <<-EOF
	nadeshiko-mpv.sh $version
	© deterenkelt 2018.
	Licence GPLv3+: GNU GPL ver. 3 or later <http://gnu.org/licenses/gpl.html>
	This is free software: you are free to change and redistribute it.
	There is no warranty, to the extent permitted by law.
	EOF
}

check_socket() {
	[ -S "$mpv_socket" ] || {
		if [ -e "$mpv_socket" ]; then
			[ -r "$mpv_socket" ] || err "“$mpv_socket” isn’t readeable."
		else
			err "“$mpv_socket” doesn’t exist."
		fi
		err "“$mpv_socket” isn’t a socket file."
	}
	return 0
}

check_prop_name() {
	local propname_to_test="$1" found
	for propname in ${!properties[@]}; do
		[ "$propname" = "$propname_to_test" ] && found=t && break
	done
	[ -v found ] || err "No such property: “$propname_to_test”."
	return 0
}

internal_set_prop() {
	local propname="$1" propval="$2" prop_true_test prop_false_test
	IFS=$'\n' read -d '' prop_true_test prop_false_test \
		< <( echo -n "${properties[$propname]}"; echo -en '\0' )
	eval ${prop_true_test:-false} \
		&& declare -g ${propname//-/_}="$propval" \
		&& declare -g ${propname//-/_}_true=t \
		&& return 0
	eval ${prop_false_test:-false} \
		&& declare -g ${propname//-/_}="$propval" \
		&& return 0

	# Undefined
	unset ${propname//-/_}
	return 1
}

get_prop() {
	local propname="$1" mpv_answer propval
	check_socket
	check_prop_name "$propname"
	mpv_answer=$(
		cat <<-EOF | socat - "$mpv_socket"
		{ "command": ["get_property_string", "$propname"] }
		EOF
	)
	# {"data":"326.994000","error":"success"}
	# {"data":"no","error":"success"}
	# {"data":null,"error":"success"}  # NB properties that may only be set,
	#                                  # return not a string, but null!
	[[ "$mpv_answer" =~ ^\{\"data\":(null|\"(.*)\"),\"error\":\"(.*)\"\}$ ]] \
		|| { err "Cannot get property $propname: JSON error."; }
	propval=${BASH_REMATCH[2]}
	status=${BASH_REMATCH[3]}
	[ "$status" != success ] && err "get_prop $propname: bad status “$status”."
	internal_set_prop "$propname" "$propval" \
		|| err "get_prop: unknown value for $propname: “$propval”"
	return 0
	# Would be good to implement check on request id – any string that
	# should be returned as it was passed.
	#
	# { "command": ["get_property", "time-pos"], "request_id": 100 }
	# { "error": "success", "data": 1.468135, "request_id": 100 }
}

get_props() {
	local propname
	for propname in "$@"; do get_prop "$propname" || return $?; done
	return 0
}

set_prop() {
	local propname="$1" propval="$2" mpv_answer status
	check_socket
	check_prop_name "$propname"
	mpv_answer=$(
		cat <<-EOF | socat - "$mpv_socket"
		{ "command": ["set_property", "$propname", "$propval"] }
		EOF
	)
	# {"error":"success"}
	# {"error":"property not found"}
	[[ "$mpv_answer" =~ ^\{\"error\":\"(.*)\"\}$ ]] \
		|| err "set_prop: “$propname” = “$propval”: JSON error"
	status=${BASH_REMATCH[1]}
	[ "$status" != success ] && err "set_prop: “$propname” = “$propval”: bad_status: “$status”."
	return 0
}

send_command() {
	local command="$1" command_args mpv_answer data status
	shift
	check_socket
	# check_command "$command"
	for arg in "$@"; do
		command_args+=", \"$arg\""
	done
	mpv_answer=$(
		cat <<-EOF | socat - "$mpv_socket"
		{ "command": ["$command"${command_args:-}] }
		EOF
	)
	# {"data":null,"error":"success"}
	# {"error":"invalid parameter"}
	[ "$mpv_answer" = '{"error":"invalid parameter"}' ] \
		&& err "send_command: “$command $*”: invalid parameter."
	[[ "$mpv_answer" =~ ^\{\"data\":(.*),\"error\":\"(.*)\"\}$ ]] \
		|| err "send_command: “$command $*”: JSON error"
	data=${BASH_REMATCH[1]}
	status=${BASH_REMATCH[2]}
	[ "$status" != success ] && err "set_prop: bad_status: “$status”."
	return 0
}

retrieve_properties() {
	for prop in ${!properties[@]}; do
		get_prop "$prop"
		declare -n propval=${prop//-/_}
		declare -n propval_if_true=${prop//-/_}_true
		echo -e "$prop\t$propval\t${propval_if_true:-f}"
	done | column -t -s $'\t'
	return 0
}


#-----------------------------------------------------------------------------

write_var_to_datafile() {
	local varname="$1" varval="$2"
	info "Setting $varname to “$varval”."
	declare -g $varname="$varval"
	sed -ri "/^$varname=/d" "$data_file"
	echo "$varname='$varval'" >> "$data_file"
	return 0
}

del_var_from_datafile() {
	local varname="$1"
	unset $varname
	info "Deleting $varname from ${data_file##*/}."
	sed -ri "/^$varname=/d" "$data_file"
	return 0
}

 # This function verifies, that all the necessary variables
#  are set at the current stage. For that it has a list of
#  variable names for each caller function.
#
check_needed_vars() {
	declare -A vars_needed=(
		[arrange_times]='time1 time2'
		[preview]='time1 time2 mute sub_visibility'
		[confirm]=''
		[encode]='time1 time2 mute sub_visibility max_size screenshot_directory working_directory'
		[post_preview]=''
	)
	for var in ${vars_needed[${FUNCNAME[1]}]}; do
		[ -v $var ] || err "func ${FUNCNAME[1]} needs variable “$var”, but it is not set."
	done
	return 0
}

put_time() {
	get_prop time-pos
	time_pos=${time_pos%???}
	if [ ! -v time1 -o -v time2 ]; then
		write_var_to_datafile time1 "$time_pos"
		send_command show-text "Time1 set"
		unset time2
		del_var_from_datafile time2
	elif [ -v time1 -a ! -v time2 ]; then
		write_var_to_datafile time2 "$time_pos"
		send_command show-text "Time2 set"
	fi
	return 0
}

arrange_times() {
	check_needed_vars
	local time_buf
	[ "$time1" = "$time2" ] && err "Time1 and Time2 are the same."
	[ "${time1%.*}" -gt "${time2%.*}" ] && {
		time_buf="$time1"
		write_var_to_datafile time1 "$time2"
		write_var_to_datafile time2 "$time_buf"
	}
	return 0
}

preview() {
	[ -v show_preview ] || return 0
	check_needed_vars
	mpv --x11-name mpv-nadeshiko-preview \
	    --start="$time1" \
	    --ab-loop-a="$time1" --ab-loop-b="$time2" \
	    --mute=$mute \
	    --sub-visibility=$sub_visibility \
	    --osd-msg1="Preview" \
	    "$path"
	return 0
}

confirm() {
	check_needed_vars
	local max_size_default max_size_small max_size_tiny kilo \
	      xdialog_retval
	eval $(sed -rn '/^\s*(max_size_|kilo)/p' "$MYDIR/nadeshiko.rc.sh")
	[ -v max_size_default ] \
		&& [ -v max_size_small ] \
		&& [ -v max_size_tiny ] \
		&& [ -v kilo ] \
		|| err "Can’t retrieve max. file sizes from nadeshiko.rc.sh."
	for fsize in max_size_default max_size_small max_size_tiny; do
		declare -n fsize_val=$fsize
		if [ "$kilo" = '1000' ]; then
			fsize_val=${fsize_val/k/ kB}
			fsize_val=${fsize_val/M/ MB}
			fsize_val=${fsize_val/G/ GB}
		elif [ "$kilo" = '1024' ]; then
			fsize_val=${fsize_val/k/ KiB}
			fsize_val=${fsize_val/M/ MiB}
			fsize_val=${fsize_val/G/ GiB}
		else
			err "kilo is set to “$kilo”, should be either 1000 or 1024."
		fi
	done
	set +eE
	traponerr unset
	max_size=$(Xdialog --stdout \
	                   --title "$MY_MSG_TITLE" \
	                   --ok-label "Create" \
	                   --cancel-label="Cancel" \
	                   --buttons-style default \
	                   --radiolist "Create clip?\n\nPick size" \
	                               324x200 0 \
	                               tiny "$max_size_tiny" off \
	                               small "$max_size_small" off \
	                               default "$max_size_default" on \
	          )
	xdialog_retval=$?
	set -e
	[ $xdialog_retval -ne 0 ] && rm "$data_file" && return 1
	write_var_to_datafile max_size "$max_size"
	return 0
}

encode() {
	check_needed_vars
	local audio subs nadeshiko_retval
	[ $mute = yes ] \
		&& audio=noaudio \
		|| audio=audio
	[ $sub_visibility = yes ] \
		&& subs=subs \
		|| subs=nosubs
	send_command show-text "Encoding" "3000"
	# Nadeshiko is a good girl and catches all errors herself.
	set +e
	"$MYDIR/nadeshiko.sh" "$time1" "$time2" "$path" \
	                      "$audio" "$subs" "$max_size" \
	                      "${screenshot_directory:-$working_directory}"
	nadeshiko_retval=$?
	set -e
	rm "$data_file"
	[ $nadeshiko_retval -eq 0 ] \
		&& send_command show-text "Encoding done." "2000" \
		|| send_command show-text "Encoding failed." "3000"
	return $nadeshiko_retval
}

post_preview() {
	[ -v show_post_preview ] || return 0
	check_needed_vars
	local last_log last_file
	pushd "$MYDIR/nadeshiko_logs" >/dev/null
	last_log=$(ls -tr | tail -n1)
	[ -r "$last_log" ] || {
		warn "Cannot get last log."
		return 1
	}
	last_file=$(
		sed -rn '/Encoded successfully/,/Copied path to/ {
			                                                n
			                                                s/^.{11}//
			                                                s/.{4}$//p  }' \
		        "$last_log"
	)
	popd >/dev/null

	mpv --x11-name mpv-nadeshiko-preview \
	    --loop-file=inf \
	    --mute=no \
	    --sub-visibility=yes \
	    --osd-msg1="Encoded file" \
	    "${screenshot_directory:-$working_directory}/$last_file"
	return 0
}

[[ "${1:-}" =~ ^(-h|--help)$ ]] && show_help && exit 0
[[ "${1:-}" =~ ^(-v|--version)$ ]] && show_version && exit 0
[ $# -ne 0 ] && show_help && exit 5

 # Test, that all the entries from our properties array
#  can be retrieved.
#
# retrieve_properties

# Check connection.
get_props mpv-version path

data_file=$(grep -rlF "$path" |& head -n1)
if [ -e "$data_file" ]; then
	# Read properties.
	eval $( sed '1d' "$data_file" )
else
	# Dump file path there.
	data_file=$(mktemp --tmpdir='.'  mpvfile.XXXX)
	echo "$path" > "$data_file"
	# Populate data_file
	get_props mute sub-visibility screenshot-directory working-directory
	write_var_to_datafile mute $mute
	write_var_to_datafile sub_visibility $sub_visibility
	write_var_to_datafile screenshot_directory "$screenshot_directory"
	write_var_to_datafile working_directory "$working_directory"
fi

put_time          \
&& [ -v time2 ]   \
&& arrange_times  \
&& preview        \
&& confirm        \
&& encode         \
&& post_preview