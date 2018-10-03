#  Should be sourced.

#  nadeshiko-do-postponed_dialogues_Xdialog.sh
#  Dialogues implemented with Xdialog.
#  deterenkelt © 2018
#
#  For licence see nadeshiko.sh


#  1. All dialogues depend on the “dialog” global variable.
#  2. dialog function is defined in bahelite_dialog.sh and calls
#     an actual $dialog.


show_dialogue_confirm_running_jobs() {
	declare -g confirmed_running_jobs
	local dialog_retval
	errexit_off
	$dialog  --stdout \
	         --ok-label "Run jobs" \
	         --cancel-label "Cancel" \
	         --buttons-style default \
	         --yesno "There are $total_jobs jobs. Run encode?" \
	         324x110
	dialog_retval=$?
	errexit_on
	[ $dialog_retval -eq 0 ] && confirmed_running_jobs=t
	return 0
}


show_dialogue_no_jobs() {
	errexit_off
	$dialog  --stdout  --buttons-style default --msgbox "No jobs!" 220x90
	errexit_on
	return 0
}