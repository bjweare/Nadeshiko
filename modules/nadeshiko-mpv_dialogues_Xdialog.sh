#  Should be sourced.

#  nadeshiko-mpv_dialogues_Xdialog.sh
#  Dialogues implemented with Xdialog, I rate them 4/5.
#  deterenkelt © 2018
#
#  For licence see nadeshiko.sh


#  1. All dialogues depend on the “dialog” global variable.
#  2. dialog function is defined in bahelite_dialog.sh and calls
#     an actual $dialog.


show_dialogue_choose_mpv_socket_Xdialog() {
	declare -g mpv_socket
	local window_height="$1"  dialog_retval
	errexit_off
	mpv_socket=$(
		dialog --stdout --no-tags  \
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


show_dialogue_choose_config_file_Xdialog() {
	declare -g nadeshiko_config
	local  window_height="$1"  dialog_retval
	errexit_off
	nadeshiko_config=$(
		dialog --stdout --no-tags  \
	           --ok-label "Choose"  \
	           --cancel-label "Cancel"  \
	           --buttons-style default  \
	           --radiolist "Choose a Nadeshiko configuration file:\n"  \
	           324x$window_height 0  \
	           "${dialog_configs_list[@]}"
	)
	dialog_retval=$?
	errexit_on
	[ $dialog_retval -eq 0 ] || abort 'Cancelled.'
	return 0
}


show_dialogue_pick_size_Xdialog() {
	local dialog_output  dialog_retval  set_fname_pfx  max_size
	errexit_off
	dialog_output=$(
		dialog --stdout --no-tags  \
		       --check "Set a custom name"  \
		       --ok-label "Create"  \
		       --cancel-label="Cancel"  \
		       --buttons-style default  \
		       --radiolist "Pick maximum size:"  \
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

	[ "$set_fname_pfx" = checked ] && {
		dialog_output=$(
			dialog --stdout --no-cancel --no-tags  \
			       --ok-label 'OK'  \
			       --buttons-style text  \
			       --inputbox "Set file name prefix.\nIt will be added at the beginning."  \
			       400x155
		) ||:

		! [[ "$dialog_output" =~ ^[[:space:]]*$ ]]  \
			&& write_var_to_datafile  fname_pfx  "$dialog_output"
	}
	return 0
}


return 0