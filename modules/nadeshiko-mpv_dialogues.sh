#  Should be sourced.

#  nadeshiko-mpv_dialogues.sh
#  Universal functions to call either Xdialog or kdialog,
#  depending on what is present on user’s end.
#  deterenkelt © 2018
#
#  For licence see nadeshiko.sh


#  1. All dialogues depend on the “dialog” global variable.
#  2. dialog function is defined in bahelite_dialog.sh and calls
#     an actual $dialog.


show_dialogue_pick_size_Xdialog() {
	declare -g  need_to_set_name
	local dialog_output  dialog_retval  set_fname_pfx  max_size
	errexit_off
	dialog_output=$(
		dialog --stdout --no-tags  \
		       --title 'Create clip'  \
		       --check "Set a custom name"  \
		       --ok-label "Create"  \
		       --cancel-label="Cancel"  \
		       --buttons-style default  \
		       --radiolist "Create clip?\n\nPick maximum size:"  \
		       324x272 0  \
		       "${variants[@]}"
	)
	dialog_retval=$?
	errexit_on
	[ $dialog_retval -eq 0 ] || {
		rm "$data_file"
		abort 'Cancelled.'
	}

	IFS=$'\n' read -d ''  max_size  set_fname_pfx < \
		<(echo -e "$dialog_output\0");
	write_var_to_datafile max_size "$max_size"
	[ "$set_fname_pfx" = checked ] && need_to_set_name=t
	return 0
}


show_dialogue_set_name_Xdialog() {
	local dialog_output
	[ -v need_to_set_name ] && {
		dialog_output=$(
			dialog --stdout --no-cancel --no-tags  \
			       --title 'Set a name'  \
			       --ok-label 'OK'  \
			       --buttons-style text  \
			       --inputbox "Enter a string to add to the encoded file name\n(will be added at the beginning)"  \
			       400x155
		) ||:

		! [[ "$dialog_output" =~ ^[[:space:]]*$ ]]  \
			&& write_var_to_datafile  fname_pfx  "$dialog_output"
	}
	return 0
}


show_dialogue_pick_size_kdialog() {
	local dialog_output  dialog_retval
	errexit_off
	dialog_output=$(
		dialog --title "Create clip"  \
		       --radiolist "Create clip?\n\nPick maximum size:"  \
		       --geometry 300x200  \
		       "${variants[@]}"  \
		       2>/dev/null
	)
	dialog_retval=$?
	errexit_on
	[ $dialog_retval -eq 0 ] || {
		rm "$data_file"
		abort 'Cancelled.'
	}

	write_var_to_datafile  max_size  "$dialog_output"
	return 0
}


show_dialogue_set_name_kdialog() {
	local dialog_output  dialog_retval
	[ -v show_name_setting_dialog ] && {
		errexit_off
		dialog_output=$(
			dialog --title 'Set a name'  \
			       --inputbox "Enter a string to add to the encoded file name"$'\n'"(will be added at the beginning)"  \
			       --geometry 400x155  \
			       2>/dev/null
		)
		dialog_retval=$?
		errexit_on
		[ $dialog_retval -eq 0 ] \
		&& ! [[ "$dialog_output" =~ ^[[:space:]]*$ ]] \
			&& write_var_to_datafile  fname_pfx  "$dialog_output"
	}
	return 0
}


show_dialogue_choose_config_file_Xdialog() {
	declare -g nadeshiko_config
	local  window_height="$1"  dialog_retval
	errexit_off
	nadeshiko_config=$(
		dialog --stdout --no-tags  \
		       --title 'Choose config'  \
	           --ok-label "Choose"  \
	           --cancel-label "Cancel"  \
	           --buttons-style default  \
	           --radiolist "Select a Nadeshiko configuration file:\n"  \
	           324x$window_height 0  \
	           "${dialog_configs_list[@]}"
	)
	dialog_retval=$?
	errexit_on
	[ $dialog_retval -eq 0 ] || abort 'Cancelled.'
	return 0
}


show_dialogue_choose_config_file_kdialog() {
	declare -g nadeshiko_config
	local  window_height="$1"  dialog_retval
	errexit_off
	nadeshiko_config=$(
		dialog --title 'Choose config'  \
	           --radiolist "Select a Nadeshiko configuration file:"  \
	           --geometry 324x$window_height  \
	           "${dialog_configs_list[@]}"  \
	           2>/dev/null
	)
	dialog_retval=$?
	errexit_on
	[ $dialog_retval -eq 0 ] || abort 'Cancelled.'
	return 0
}


show_dialogue_choose_mpv_socket_Xdialog() {
	declare -g mpv_socket
	local window_height="$1"  dialog_retval
	errexit_off
	mpv_socket=$(
		dialog --stdout --no-tags  \
		       --title "Choose an mpv socket"  \
		       --ok-label "Choose"  \
		       --cancel-label "Cancel"  \
		       --buttons-style default  \
		       --radiolist "Choose an mpv socket:\n"  \
		       324x$window_height 0  \
		       "${dialog_socket_list[@]}"
	)
	dialog_retval=$?
	errexit_on
	[ $dialog_retval -eq 0 ] || abort 'Cancelled.'
	return 0
}


show_dialogue_choose_mpv_socket_kdialog() {
	declare -g mpv_socket
	local window_height="$1"  dialog_retval
	errexit_off
	mpv_socket=$(
		dialog --title "Choose an mpv socket"  \
		       --radiolist "Choose an mpv socket:"  \
		       --geometry 324x$dialog_window_height   \
		       "${dialog_socket_list[@]}"  \
		       2>/dev/null
	)
	dialog_retval=$?
	errexit_on
	[ $dialog_retval -eq 0 ] || abort 'Cancelled.'
	return 0
}


return 0