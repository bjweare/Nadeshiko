# Should be sourced.

#  bahelite_messages_to_desktop.sh
#  To send notifications to desktop with notify-send.
#  deterenkelt © 2019

#  Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	echo 'Must be sourced from bahelite.sh.' >&2
	return 5
}
. "$BAHELITE_DIR/bahelite_messages.sh" || return 5

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_MESSAGES_TO_DESKTOP_VER ] && return 0
#  Declaring presence of this module for other modules.
BAHELITE_MODULE_MESSAGES_TO_DESKTOP_VER='1.0'

BAHELITE_INTERNALLY_REQUIRED_UTILS+=(
	notify-send   # (libnotify or libtinynotify)
)


 # Desktop notifications
#
#  To send a notification to both console and desktop, main script should
#  call info-ns(), warn-ns() or err() functions, which are defined
#  in bahelite_messages.sh.


 # Define this variable to make notifications with icons.
#
# export MSG_NOTIFYSEND_USE_ICON=t


 # Shows a desktop notification
#  $1 – message.
#  $2 – icon type: empty, “information”, “warning” or “error”.
#
bahelite_notify_send() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local msg="$1" type="$2" duration urgency icon
	msg=${msg##+([[:space:]])}
	msg=${msg%%+([[:space:]])}
	case "$type" in
		error|dialog-error)
			icon='dialog-error'
			urgency=critical
			duration=10000
			;;
		warning|dialog-warning)
			icon='dialog-warning'
			urgency='normal'
			duration=10000
			;;
		info|information)
			icon='info'
			urgency='normal'
			duration=3000
			;;
	esac
	[ -v MSG_NOTIFYSEND_USE_ICON ] || unset icon
	#  The hint is for the message to not pile in the stack – it is limited.
	notify-send --hint int:transient:1  \
	            --urgency "$urgency"  \
	            -t $duration  \
	            "${MY_DISPLAY_NAME^}"  "$msg"  \
	            ${icon:+--icon=$icon}
	return 0
}



export -f  bahelite_notify_send

return 0
