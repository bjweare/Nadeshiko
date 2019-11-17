#  Should be sourced.

#  messages_to_desktop.sh
#  To send notifications to desktop with notify-send.
#  © deterenkelt 2019

#  Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	cat <<-EOF  >&2
	Bahelite error on loading module ${BASH_SOURCE##*/}:
	load the core module (bahelite.sh) first.
	EOF
	return 4
}

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_MESSAGES_TO_DESKTOP_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_MESSAGES_TO_DESKTOP_VER='1.1.5'

BAHELITE_INTERNALLY_REQUIRED_UTILS+=(
	notify-send
)

BAHELITE_INTERNALLY_REQUIRED_UTILS_HINTS+=(
	[notify-send]='notify-send belongs to the libnotify package
	https://developer.gnome.org/libnotify/'
)


(( $# != 0 )) && {
	echo "Bahelite module “messages_to_desktop” doesn’t take arguments!"  >&2
	[ "$*" = help ]  \
		&& return 0  \
		|| return 4
}



                      #  Desktop notifications  #

 # To send a notification to both console and desktop, main script should
#  call info-ns(), warn-ns() or err() functions, which are defined
#  in bahelite_messages.sh.
#
#  To suppress sending certain desktop notifications or completely disable
#  them, set VERBOSITY_LEVEL to xxxxNx, where N can be a number from the
#  following list:
#  0 – turn off all messages
#  1 – show only error messages (type == err|error|dialog-error)
#  2 – show only error and warning messages (type == err|error|dialog-error|
#      warn|warning|dialog-warning)
#  3–9 – show all messages.


 # Define this variable to make notifications with icons.
#
# declare -gx MSG_NOTIFYSEND_USE_ICON=t


 # Shows a desktop notification
#  $1 – message.
#  $2 – icon type: empty, “information”, “warning” or “error”.
#
bahelite_notify_send() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	case "$(get_bahelite_verbosity  desktop)" in
		0)	return 0
			;;

		1)	[[ "$type" =~ ^(dialog-|)(info(rmation|)|warn(ing|))$ ]]  \
				&& return 0
			;;

		2)	[[ "$type" =~ ^(dialog-|)info(rmation|)$ ]]  \
				&& return 0
			;;
	esac
	local msg="$1" type="${2:-info}" duration urgency icon
	msg=${msg##+([[:space:]])}
	msg=${msg%%+([[:space:]])}
	#
	#  Support all the possible variations, that may come to mind to the
	#  author of the main script: bahelite function names and notify-send
	#  icons (along with the inconsistency in the icon names, that is
	#  with or without “dialog-” prefix).
	#
	case "$type" in
		err|error|dialog-error)
			icon='dialog-error'
			urgency=critical
			duration=10000
			;;
		warn|warning|dialog-warning)
			icon='dialog-warning'
			urgency='normal'
			duration=10000
			;;
		info|information|dialog-information)
			icon='info'
			urgency='normal'
			duration=3000
			;;
	esac

	[ -v MSG_NOTIFYSEND_USE_ICON ] || unset icon

	(
		 # Dbus session address may be stale in the environment, – and to force
		#    applications to evaluate it at runtime, this variable must be
		#    unset. Displaying a desktop message is of critical importance for
		#    the scripts not running from the terminal. The lack of a message
		#    may lead to confusion.
		#  The value in the environment variable gets stale, if the shell was
		#    spawned during one Dbus session, but it was closed, and the shell
		#    now runs in another. This is common for applications like tmux
		#    and screen, that usually persist between X sessions.
		#  As the variable is a global one, unsetting it in the global scope
		#    may lead to unforseen consequences, hence the subshell.
		#
		unset DBUS_SESSION_BUS_ADDRESS
		#  The hint is for the message to not pile in the stack –
		#  it is limited.
		notify-send --hint int:transient:1  \
		            --urgency "$urgency"  \
		            -t $duration  \
		            "$MY_DISPLAY_NAME"  "$msg"  \
		            ${icon:+--icon=$icon}
	)
	return 0
}
export -f  bahelite_notify_send



return 0