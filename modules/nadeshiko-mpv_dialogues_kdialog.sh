#  Should be sourced.

#  nadeshiko-mpv_dialogues_kdialog.sh
#  Dialogues implemented with kdialog. I rate them 3/5.
#  deterenkelt © 2018
#
#  For licence see nadeshiko.sh


#  1. All dialogues depend on the “dialog” global variable.
#  2. dialog function is defined in bahelite_dialog.sh and calls
#     an actual $dialog.


show_dialogue_choose_mpv_socket_kdialog() {
	declare -g mpv_socket
	local window_height="$1"  dialog_retval
	errexit_off
	mpv_socket=$(
		dialog --radiolist "Choose an mpv socket:"  \
		       --geometry 324x$dialog_window_height   \
		       "${dialog_socket_list[@]}"  \
		       2>/dev/null
	)
	dialog_retval=$?
	errexit_on
	[ $dialog_retval -eq 0 ] || abort 'Cancelled.'
	return 0
}


show_dialogue_choose_config_file_kdialog() {
	declare -g nadeshiko_preset
	local  window_height="$1"  dialog_retval
	errexit_off
	nadeshiko_preset=$(
		dialog --radiolist "Choose a Nadeshiko configuration file:"  \
	           --geometry 324x$window_height  \
	           "${dialog_configs_list[@]}"  \
	           2>/dev/null
	)
	dialog_retval=$?
	errexit_on
	[ $dialog_retval -eq 0 ] || abort 'Cancelled.'
	return 0
}


show_dialogue_pick_size_kdialog() {
	local dialog_output  dialog_retval
	errexit_off
	dialog_output=$(
		dialog --radiolist "Pick maximum size:"  \
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

	[ -v show_name_setting_dialog ] && {
		errexit_off
		dialog_output=$(
			dialog --inputbox "Set file name prefix."$'\n'"It will be added at the beginning."  \
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


return 0