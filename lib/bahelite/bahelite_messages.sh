# Should be sourced.

#  bahelite_messages.sh
#  Provides messages for console and desktop.
#  deterenkelt © 2018–2019

#  Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	echo 'Must be sourced from bahelite.sh.' >&2
	return 5
}
. "$BAHELITE_DIR/bahelite_colours.sh" || return 5
. "$BAHELITE_DIR/bahelite_misc.sh" || return 5

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_MESSAGES_VER ] && return 0
#  Declaring presence of this module for other modules.
BAHELITE_MODULE_MESSAGES_VER='2.4'



                         #  Message types  #

#  See the wiki. (It’s not written yet.)



                        #  Verbosity levels  #

 # Lvl  Destination    What messages go to that destination and notes.
#
#  0    Log            none (if logging is enabled at all).
#       Console        none.
#       Desktop        none.
#                                           Note
#                         Only the exit codes will tell about errors
#                                      on this level.
#
#  1    Log            all messages.
#       Console        none.
#       Desktop        none.
#
#  2    Log            all messages.
#       Console        all messages.
#       Desktop        none.
#
#  3    Log            only *err*(), redmsg() and whatever output that goes
#                      to stderr in the main script. (Stdout is essentially
#                      redirected to /dev/null.)
#       Console        ——»——
#       Desktop        only *err*().
#
#  4    Log            Everything, but *info*().
#       Console        ——»——
#       Desktop        all desktop messages.¹
#
#  5    Log            all messages.
#       Console        all messages.
#       Desktop        all desktop messages.¹
#                                           Note
#                                This is the default level.
#
#  6    —————————————————————————RESERVED—————————————————————————————————————
#
#  7    Log            all messages. Enables the internal module messages, if
#                      module is enabled in BAHELITE_MODULE_VERBOSITY.
#       Console        ——»——
#       Desktop        all desktop messages.¹
#
#  8    —————————————————————————RESERVED—————————————————————————————————————
#
#  9    Log            all messages plus the internal messages enabled on L7.
#                      Turns on xtrace shell option, when Bahelite finishes
#                      loading.
#       Console        ——»——
#       Desktop        all desktop messages.¹
#
#  10   Log            all messages plus the internal messages enabled on L7.
#                      Turns on xtrace shell option, when Bahelite finishes
#                      loading and unsets BAHELITE_HIDE_FROM_XTRACE.
#       Console        ——»——
#       Desktop        all desktop messages.¹
#
#
#  Notes
#  1. Desktop messages are those sent with info-ns(), warn-ns() and err().
#  2. Desktop messages are sent only as long as NO_DESKTOP_NOTIFICATIONS
#     remains undefined. (See below.)
#  3. Logging is enabled only if the logging module was included
#     in the main script and it called start_log(). That function also
#     controls verbosity of the log output.
#  4. The verbosity of console and desktop functions is controlled in the
#     __msg() below.
#
[ -v BAHELITE_VERBOSITY_LEVEL ] \
	|| export BAHELITE_VERBOSITY_LEVEL=5



                         #  Message lists  #

 # Internal message lists
#
declare -Ax BAHELITE_INFO_MESSAGES=()
declare -Ax BAHELITE_WARNING_MESSAGES=()
#
 # Error messages
#  Keys are used as parameters to err() and values are printed via msg().
#  The keys can contain spaces – e.g. ‘my key’. Passing them to err() doesn’t
#    require quoting and the number of spaces is not important.
#  You can localise messages by redefining this array in some file
#    and sourcing it.
#
declare -Ax BAHELITE_ERROR_MESSAGES=(
	[no such msg]='No such message keyword: “$1”.'
	[no util]='Utils are missing: $1.'
)
#
#
 # User lists
#  By default, functions like info(), warn(), err() will accept a text string
#  and display it. However, it’s possible to replace strings with keywords
#  and hold them separately. This comes handy, when
#  - the messages are too big and ruin the length of lines in the code;
#  - especially when you’d like to use the text of the message as a template,
#    and pass parameters to err(), so that it would substitute them – making
#    a big string with big variable names inside may be really ugly.
#  - when you want to localise your script and keep language-agnostic keywords
#    in the code while pulling the actual messages from a file with localisa-
#    tion.
#  In order to enable keyword-based messages, define MSG_USE_KEYWORDS with
#  any value in the main script. This will switch off the messaging system
#  to arrays.
#
# declare -x MSG_USE_KEYWORDS=t
#
declare -Ax INFO_MESSAGES=()
declare -Ax WARNING_MESSAGES=()
declare -Ax ERROR_MESSAGES=()
#
#  Custom exit codes, the keys should be the same as in ERROR_MESSAGES.
declare -Ax ERROR_CODES=()

 # Colours for the console and log messages
#  Regular functions (info, warn, err) apply the colour only to the asterisk.
#
export INFO_MESSAGE_COLOUR=$__green
export WARN_MESSAGE_COLOUR=$__yellow
export ERR_MESSAGE_COLOUR=$__red
export PLAIN_MESSAGE_COLOUR=$__fg_rst

 # Define this variable to start each message not with just an asterisk
#    ex:  * Stage 01 completed.
#  but with a keyword that would define the type of the message. Especially
#  handy if you use MSG_NO_COLOURS=t to suppress colours.
#    ex:  * INFO: Stage 01 completed.
#
# export MSG_ASTERISK_WITH_MSGTYPE=t
#
#
 # Define this variable in the main script to disable colouring the messages.
#  This will not untie the dependencies to the colours module. The variables
#  from bahelite_colours.sh will still be available, however, they will be
#  stripped or not added to any *info*() *warn*() or *err*() messages.
#
# export MSG_NO_COLOURS=t
#
#
 # When printing to console/logs, use “fold” for better appearance. This uti-
#  lity, however, is not aware of wide characters (in the bit-wise sense),
#  so if you deal with non-ascii characters, you may get only 1/2 of the
#  terminal width used.
#
# export MSG_FOLD_MESSAGES=t

 # Message indentation level
#  Checking, if it’s already set, in case one script calls another –
#  so that indentaion would be inherited in the inner script.
[ -v BAHELITE_MI_LEVEL ]  \
	|| export BAHELITE_MI_LEVEL=0
#
#  The whitespace indentation itself.
#  As it belongs to markup, that user may use, it follows
#  the corresponding style, akin to terminal sequences.
[ -v __mi ] \
	|| export __mi=''
#
#  Number of spaces to use per indentation level.
#  No tabs, because predicting the tab length in a particular terminal
#  is impossible anyway.
[ -v BAHELITE_MI_SPACENUM ]  \
	|| export BAHELITE_MI_SPACENUM=4


 # Assembles __mi according to the current BAHELITE_MI_LEVEL
#
mi_assemble() {
	#  Internal! No xtrace_off/on needed!
	declare -g __mi=''
	local i
	for (( i=0; i < (BAHELITE_MI_LEVEL*BAHELITE_MI_SPACENUM); i++ )); do
		__mi+=' '
	done
	#  Without this, multiline messages that occur on BAHELITE_MI_LEVEL=0,
	#  when $__mi is empty, won’t be indented properly. ‘* ’, remember?
	[ "$__mi" ] || __mi='  '
	return 0
}


 # Increments the indentation level.
#  [$1] — number of times to increment $MI_LEVEL.
#         The default is to increment by 1.
#
milinc() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local count=${1:-1}  z
	for ((z=0; z<count; z++)); do
		let '++BAHELITE_MI_LEVEL || 1'
	done
	mi_assemble || return $?
}


 # Decrements the indentation level.
#  [$1] — number of times to decrement $MI_LEVEL.
#  The default is to decrement by 1.
#
mildec() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local count=${1:-1}  z
	if (( BAHELITE_MI_LEVEL == 0 )); then
		warn "No need to decrease indentation, it’s on the minimum."
	else
		for ((z=0; z<count; z++)); do
			let '--BAHELITE_MI_LEVEL || 1'
		done
		mi_assemble || return $?
	fi
	return 0
}


 # Sets the indentation level to a specified number.
#  $1 – desired indentation level, 0..9999.
#
milset () {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local mi_level=${1:-}
	[[ "$mi_level" =~ ^[0-9]{1,4}$ ]] || {
		warn "Indentation level should be an integer between 0 and 9999."
		return 0
	}
	BAHELITE_MI_LEVEL=$mi_level
	mi_assemble || return $?
}


 # Removes any indentation.
#
mildrop() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	BAHELITE_MI_LEVEL=0
	mi_assemble || return $?
}



              #  Messages to console, log and desktop  #

 # Some of the message functions below send messages only to log, and not
#  console and not to desktop.
#
#
 # Message properties
#
# __msg_properties=(
# 	#  A role is an anchor, that tells about the sense, the context,
# 	#  in which a certain message is used. It explains, why the rest
# 	#  of the properties ended up in such a set.
# 	[role]=''
# 	#  If MSG_USE_KEYWORDS is set, then the actual texts and exit codes
# 	#  would be taken from there.
# 	[message_array]=''
# 	#  The colour to output the asterisk with. For certain types the en-
# 	#  tire message is coloured. When MSG_ASTERISK_WITH_MSGTYPE is set,
# 	#  a type (role) of the message is added to the asterisk and gets
# 	#  coloured too. If MSG_NO_COLOURS is defined, the message will go
# 	#  in plain text.
# 	[colour]=''
# 	#  Whether only the asterisk at the beginning, or the entire message
# 	#  should be coloured.
# 	[whole_message_in_colour]=''
# 	#  The string, that has an asterisk, space next to it, and the message
# 	#  type/role, if MSG_ASTERISK_WITH_MSGTYPE is set.
# 	[asterisk]=''
# 	#  A string, that etermines, whether the message should go desktop
# 	#  (at the default BAHELITE_VERBOSITY level). Should be “yes” or “no”.
# 	[desktop_message]=''
# 	#  The type of message to pass for “notify-send”, if the message goes
# 	#  to desktop. Either “info”, “dialog-warning” or “dialog-error”.
# 	#  This type also determines urgency in bahelite_notify_send().
# 	[desktop_message_type]=''
# 	#  Whether the message is wholesome or it’s just a part of a compound
# 	#  message. Setting “yes” here makes the console message to be printed
# 	#  without a newline on the end, and the output can continue on this
# 	#  same line. For most messages this is set to “no”. Desktop messages
# 	#  ignore this option – even there’d be a newline on the end, it will
# 	#  be cut.
# 	[stay_on_line]=''
# 	#  Whether the message should go to “stdout” or “stderr” (at the
# 	#  default BAHELITE_VERBOSITY_LEVEL).
# 	[redir]=''
# 	#  Whether the message is internal, i.e. generated by Bahelite itself.
# 	#  Internal messages always use keywords, and this is a hook to tell
# 	#  __msg to enter the necessary part of code without activating
# 	#  MSG_USE_KEYWORDS.
# 	[internal]=''
# 	#  Whether the message should also initiate an exit from the program.
# 	#  Only *err*() and abort() use exit codes. All other message func-
# 	#  tion don’t have an exit code and __msg will simply return.
# 	[exit_code]=''
# )


 # Shows an info message.
#  $1 — a message or a key of an item in the corresponding array containing
#       the messages. Depends on whether $MSG_USE_KEYWORDS is set (see above).
#
info() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	declare -A __msg_properties=(
		[role]='info'
		[message_array]='INFO_MESSAGES'
		[colour]='INFO_MESSAGE_COLOUR'
		[whole_message_in_colour]='no'
		[asterisk]="* ${MSG_ASTERISK_WITH_MSGTYPE:+INFO: }"
		[desktop_message]='no'
		[desktop_message_type]=''
		[stay_on_line]='no'
		[redir]='stdout'
		[internal]='no'
		[exit_code]=''
	)
	__msg "$@"
	return 0
}

 # Same as info(), but omits the ending newline, like “echo -n” does.
#  This allows to print whatever with just simple “echo” later.
#
infon() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	declare -A __msg_properties=(
		[role]='info'
		[message_array]='INFO_MESSAGES'
		[colour]='INFO_MESSAGE_COLOUR'
		[whole_message_in_colour]='no'
		[asterisk]="* ${MSG_ASTERISK_WITH_MSGTYPE:+INFO: }"
		[desktop_message]='no'
		[desktop_message_type]=''
		[stay_on_line]='yes'
		[redir]='stdout'
		[internal]='no'
		[exit_code]=''
	)
	__msg "$@"
	return 0
}

 # Like info(), but has a higher rank than usual info(),
#  which allows its message to be also shown on desktop.
#  $1 – a message to be shown both in console and on desktop.
#
info-ns() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	declare -A __msg_properties=(
		[role]='info'
		[message_array]='INFO_MESSAGES'
		[colour]='INFO_MESSAGE_COLOUR'
		[whole_message_in_colour]='no'
		[asterisk]="* ${MSG_ASTERISK_WITH_MSGTYPE:+INFO: }"
		[desktop_message]='yes'
		[desktop_message_type]='info'
		[stay_on_line]='no'
		[redir]='stdout'
		[internal]='no'
		[exit_code]=''
	)
	__msg "$@"
	return 0
}


 # Shows an info message and waits for the given command to finish,
#  to print its result, and if it’s not zero, print the output
#  of that command.
#
#  $1 – a message. Something like ‘Starting up servicename… ’
#  $2 – a command.
#  $3 – any string to force the output even if the result is [OK].
#       Handy for faulty programs that return 0 even on error.
#
info-wait() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local message=$1 command=$2 force_output="$3" outp result
	declare -A __msg_properties=(
		[role]='info'
		[message_array]='INFO_MESSAGES'
		[colour]='INFO_MESSAGE_COLOUR'
		[whole_message_in_colour]='yes' # T/F
		[asterisk]="  ${MSG_ASTERISK_WITH_MSGTYPE:+RUNNING: }"
		[desktop_message]='no'
		[desktop_message_type]=''
		[stay_on_line]='yes'
		[redir]='stdout'
		[internal]='no'
		[exit_code]=''
	)
	__msg "$message"

	outp=$( bash -c "$command" 2>&1 )
	result=$?
	[ $result -eq 0 ] \
		&& printf "${__bri}%s${__g}%s${__s}${__bri}%s${__s}\n"  ' [ ' OK ' ]' \
		|| printf "${__bri}%s${__r}%s${__s}${__bri}%s${__s}\n"  ' [ ' Fail ' ]'
	[ $result -ne 0 -o "$force_output" ] && {
		milinc
		info "Here is the output of ‘$command’:"
		msg "$outp"
		mildec
	}
	return 0
}


 # Like info, but the output goes to stderr.
#
warn() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	declare -A __msg_properties=(
		[role]='warn'
		[message_array]='WARNING_MESSAGES'
		[colour]='WARN_MESSAGE_COLOUR'
		[whole_message_in_colour]='no'
		[asterisk]="* ${MSG_ASTERISK_WITH_MSGTYPE:+WARNING: }"
		[desktop_message]='no'
		[desktop_message_type]=''
		[stay_on_line]='no'
		[redir]='stdout'
		[internal]='no'
		[exit_code]=''
	)
	__msg "$@"
	return 0
}


 # Like warn(), but has a higher rank than usual info(),
#  which allows its message to be also shown on desktop.
#  $1 – a message to be shown both in console and on desktop.
#
warn-ns() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	declare -A __msg_properties=(
		[role]='warn'
		[message_array]='WARNING_MESSAGES'
		[colour]='WARN_MESSAGE_COLOUR'
		[whole_message_in_colour]='no'
		[asterisk]="* ${MSG_ASTERISK_WITH_MSGTYPE:+WARNING: }"
		[desktop_message]='yes'
		[desktop_message_type]='dialog-warning'
		[stay_on_line]='no'
		[redir]='stderr'
		[internal]='no'
		[exit_code]=''
	)
	__msg "$@"
	return 0
}


 # Shows an error message and calls “exit”.
#  Good to show a resume of the error. For the big descriptions better
#    use redmsg() before calling err().
#  The exit code is 5, unless you explicitly set MSG_USE_KEYWORDS and defined
#    error messages with corresponding codes in that array.
#
err() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	declare -A __msg_properties=(
		[role]='err'
		[message_array]='ERROR_MESSAGES'
		[colour]='ERR_MESSAGE_COLOUR'
		[whole_message_in_colour]='no'
		[asterisk]="* ${MSG_ASTERISK_WITH_MSGTYPE:+ERROR: }"
		[desktop_message]='yes'
		[desktop_message_type]='dialog-error'
		[stay_on_line]='no'
		[redir]='stderr'
		[internal]='no'
		[exit_code]='5'
	)
	__msg "$@"
	#  ^ Exits.
}

 # Has the appearance of err(), but doesn’t call “exit” afterwards.
#  It suites for printing big descriptive messages to console/logs,
#  while using err() to print the final – short! – message, that is also
#  suites to be shows as a desktop notification.
#
redmsg() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	declare -A __msg_properties=(
		[role]='redmsg'
		[message_array]='ERROR_MESSAGES'
		[colour]='ERR_MESSAGE_COLOUR'
		[whole_message_in_colour]='no'
		[asterisk]="* ${MSG_ASTERISK_WITH_MSGTYPE:+ERROR: }"
		[desktop_message]='no'
		[desktop_message_type]=''
		[stay_on_line]='no'
		[redir]='stderr'
		[internal]='no'
		[exit_code]=''
	)
	__msg "$@"
	return 0
}

 # Same as err(), but prints the whole line in red.
#
errw() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	declare -A __msg_properties=(
		[role]='err'
		[message_array]='ERROR_MESSAGES'
		[colour]='ERR_MESSAGE_COLOUR'
		[whole_message_in_colour]='yes'
		[asterisk]="  ${MSG_ASTERISK_WITH_MSGTYPE:+ERROR: }"
		[desktop_message]='yes'
		[desktop_message_type]='dialog-error'
		[stay_on_line]='no'
		[redir]='stderr'
		[internal]='no'
		[exit_code]='5'
	)
	__msg "$@"
	#  ^ Exits.
}

 # Like err(), but has the appearance of info message to both console
#  and desktop. For the case when user aborts an action – for him this is
#  something exprected and normal, while error is for the unexpected and wrong.
#
abort() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	declare -A __msg_properties=(
		[role]='abort'
		[message_array]='INFO_MESSAGES'
		[colour]='INFO_MESSAGE_COLOUR'
		[whole_message_in_colour]='no'
		[asterisk]="* ${MSG_ASTERISK_WITH_MSGTYPE:+ABORT: }"
		[desktop_message]='yes'
		[desktop_message_type]='info'
		[stay_on_line]='no'
		[redir]='stdout'
		[internal]='no'
		[exit_code]='6'
	)
	__msg "$@"
	#  ^ Exits.
}


 # For Bahelite internal warnings and errors.
#  These functions use BAHELITE_*_MESSAGES and should be preferred
#  for use within Bahelite.
#
iwarn() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	declare -A __msg_properties=(
		[role]='warn'
		[message_array]='BAHELITE_WARNING_MESSAGES'
		[colour]='WARN_MESSAGE_COLOUR'
		[whole_message_in_colour]='no'
		[asterisk]="* ${MSG_ASTERISK_WITH_MSGTYPE:+WARNING: }"
		[desktop_message]='no'
		[desktop_message_type]=''
		[stay_on_line]='no'
		[redir]='stdout'
		[internal]='yes'
		[exit_code]=''
	)
	__msg "$@"
	return 0
}


ierr() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	declare -A __msg_properties=(
		[role]='err'
		[message_array]='BAHELITE_ERROR_MESSAGES'
		[colour]='ERR_MESSAGE_COLOUR'
		[whole_message_in_colour]='no'
		[asterisk]="* ${MSG_ASTERISK_WITH_MSGTYPE:+ERROR: }"
		[desktop_message]='yes'
		[desktop_message_type]='dialog-error'
		[stay_on_line]='no'
		[redir]='stderr'
		[internal]='yes'
		[exit_code]='4'
	)
	__msg "$@"
	#  ^ Exits.
}


 # For internal use in alias functions, such as infow(), where we cannot use
#    __msg() as is, because FUNCNAME[1] will be set to the name of that alias
#    function. Hence, to avoid additions and get a plain msg(), we must call
#    it from another function, for which no additions are specified in msg().
#  It can, however, be use in the main script for a message lower in level
#    than info, that still maintains the indentation.
#
msg() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	declare -A __msg_properties=(
		[role]='plainmsg'
		[message_array]='BAHELITE_INFO_MESSAGES'
		[colour]='PLAIN_MESSAGE_COLOUR'
		[whole_message_in_colour]='no'
		[asterisk]="  "
		[desktop_message]='no'
		[desktop_message_type]=''
		[stay_on_line]='no'
		[redir]='stdout'
		[internal]='no'
		[exit_code]=''
	)
	__msg "$@"
	return 0
}


 # Shows an info, a warning or an error message
#  on console and optionally, on desktop too.
#  $1 — a text message or,
#
#       if MSG_USE_KEYWORDS is set, a key from
#         - INFO_MESSAGES, if called as *info*();
#         - WARNING_MESSAGES,  if called as *warn*();
#         - ERROR_MESSAGES, if called as *err*();
#         - PLAIN_MESSAGES, if called as msg().
#       That key may contain spaces, and the number of spaces between words
#       in the key is not important, i.e.
#         $ warn "no needed file found"
#         $ warn  no needed file found
#       and
#         $ warn  no   needed  file     found
#       will use the same item in the WARNING_MESSAGES array.
#
__msg() {
	#  Internal! There should be no xtrace_off!
	declare -g  BAHELITE_STIPULATED_ERROR
	local role  message_array  colour  whole_message_in_colour  asterisk  \
	      desktop_message  desktop_message_type  stay_on_line  redir  \
	      internal  exit_code  \
	      f  f_count=0  \
	       message=''  message_key  message_key_exists  \
	       _message=''  message_nocolours

	#  As a precaution against internal bugs, check how many times __msg()
	#  is called in the call stack. If the number will be more than 3,
	#  this hints at a recursive error.
	for f in "${FUNCNAME[@]}"; do
		[ "$f" = "${FUNCNAME[0]}" ] && let '++f_count || 1'
	done
	(( f_count >= 3 )) && {
		echo "Bahelite error: call to ${FUNCNAME[0]} went into recursion." >&2
		[ "$(type -t bahelite_print_call_stack)" = 'function' ]  \
			&& bahelite_print_call_stack
		#  Unsetting the trap, or the recursion may happen again.
		trap '' EXIT TERM INT HUP PIPE
		#  Now the script will exit guaranteely.
		exit 4
	}

	role=${__msg_properties[role]}
	declare -n message_array=${__msg_properties[message_array]}
	[ -v MSG_NO_COLOURS ]  \
		|| declare -n colour=${__msg_properties[colour]}
	is_true  __msg_properties[whole_message_in_colour] \
		&& whole_message_in_colour=${__msg_properties[whole_message_in_colour]}
	asterisk=${__msg_properties[asterisk]}
	is_true  __msg_properties[desktop_message]  \
		&& desktop_message=${__msg_properties[desktop_message]}
	desktop_message_type=${__msg_properties[desktop_message_type]}
	is_true  __msg_properties[stay_on_line]  \
		&& stay_on_line=${__msg_properties[stay_on_line]}
	redir=${__msg_properties[redir]}
	is_true  __msg_properties[internal]  \
		&& internal=${__msg_properties[internal]}
	[[ "${__msg_properties[exit_code]}" =~ ^[0-9]{1,3}$ ]]  \
		&& exit_code=${__msg_properties[exit_code]}

	case "$BAHELITE_VERBOSITY_LEVEL" in
		0)	redir='devnull'
			;;

		2)	unset desktop_message
			;;

		3)	[ "$redir" = 'stdout' ]  \
		        && redir='devnull'
			[ "$role" != 'err' ] && [ -v desktop_message ]  \
				&& unset  desktop_message
			;;

		4)	[[ "$role" =~ ^(info|plainmsg)$ ]]  \
				&& redir='devnull'
			;;
	esac

	if [ -v MSG_USE_KEYWORDS  -o  -v internal ]; then
		#  What was passed to us is not a message per se,
		#  but a key in the messages array.
		message_key="${1:-}"
		for key in "${!message_array[@]}"; do
			[ "$key" = "$message_key" ] && message_key_exists=t
		done
		if [ -v message_key_exists ]; then
			#  Positional parameters "$2..n" now can be substituted
			#  into the message strings. To make these substitutions go
			#  from the number 1, drop the $1, holding the message key.
			shift
			eval message=\"${message_array[$message_key]}\"
		else
			ierr 'no such msg' "$message_key"
		fi
	else
		message="${1:-No message?}"
	fi
	#  Removing blank space before message lines.
	#  This allows strings to be split across lines and at the same time
	#  be well-indented with tabs and/or spaces – indentation will be cut
	#  from the output.
	message=$(sed -r 's/^\s*//; s/\n\t/\n/g' <<<"$message")
	#  Before the message gets coloured, prepare a plain version.
	[ -v MSG_NO_COLOURS ]  \
		&& message_nocolours="$message"  \
		|| message_nocolours="$(strip_colours "$message")"
	_message+="${colour:-}"
	_message+="$asterisk"
	_message+="${whole_message_in_colour:-$__stop}"
	_message+="$message"
	_message+="${whole_message_in_colour:+$__stop}"
	#  See the description to MSG_FOLD_MESSAGES.
	if [ -v MSG_FOLD_MESSAGES ]; then
		message=$(echo -e ${stay_on_line:+-n} "$_message" \
		              | fold  -w $((TERM_COLS - ${#__mi} -2)) -s \
		              | sed -r "1s/^/${__mi#  }/; 1!s/^/$__mi/g" )
	else
		message=$(echo -e ${stay_on_line:+-n} "$_message" \
		              | sed -r "1s/^/${__mi#  }/; 1!s/^/$__mi/g" )
	fi
	case "$redir" in
		stdout)  echo ${stay_on_line:+-n} "$message"  ;;
		stderr)  echo ${stay_on_line:+-n} "$message" >&2  ;;
		devnull) :  ;;
	esac
	if	[ -v desktop_message ]  \
		&& [ "$(type -t bahelite_notify_send)" = 'function' ]
	then
		bahelite_notify_send "$message_nocolours" "$desktop_message_type"
	fi
	[ "$role" = err ] && BAHELITE_STIPULATED_ERROR=t
	[[ "$role" =~ ^(err|abort)$ ]] && {
		(( BASH_SUBSHELL > 0 ))  \
			&& touch "$TMPDIR/BAHELITE_STIPULATED_ERROR_IN_SUBSHELL.$BAHELITE_STARTUP_ID"
		#  If this is an error message, we must also quit
		#  with a certain exit code.
		if	[ -v internal ]; then
			exit $exit_code
		elif  [ -v MSG_USE_KEYWORDS ] \
		      &&  bahelite_verify_error_code "${ERROR_CODES[$*]}"
		then
			exit ${ERROR_CODES[$*]}
		else
			exit $exit_code
		fi
	}
	return 0
}



bahelite_xtrace_off
mi_assemble
bahelite_xtrace_on

export -f  mi_assemble  \
           milinc  \
           mildec  \
           milset  \
           mildrop  \
           __msg  \
               info  \
                   infon  \
                   info-ns  \
                   info-wait  \
               warn  \
                   warn-ns  \
                   iwarn  \
               err  \
                   redmsg  \
                   errw  \
                   abort  \
                   ierr  \
               msg

return 0