#  Should be sourced.

#  message_indentation.sh
#  Allows to shift and remember the indentation level for output messages,
#  especially handy in the scripts running one from within another.
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
[ -v BAHELITE_MODULE_MESSAGE_INDENTATION_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_MESSAGE_INDENTATION_VER='1.0'


(( $# != 0 )) && {
	echo "Bahelite module “message_indentation” doesn’t take arguments!"  >&2
	[ "$*" = help ]  \
		&& return 0  \
		|| return 4
}


 # Checking, if it’s already set, in case one script calls another –
#  so that indentaion would be inherited in the inner script.
#
[ -v MSG_INDENTATION_LEVEL ]  \
	|| declare -gx MSG_INDENTATION_LEVEL=0
#
#
#  So that mildrop() could decrease the level properly in chainloaded scripts.
#
declare -gx MSG_INDENTATION_LEVEL_UPON_ENTRANCE=$MSG_INDENTATION_LEVEL
#
#
#  The whitespace indentation itself.
#  As it belongs to markup, that user may use in the main script for custom
#    messages, it follows the corresponding style, akin to terminal sequences.
#  The string will be set according too the MSG_INDENTATION_LEVEL on the call
#    to mi_assemble() below.
#
declare -gx __mi=''
#
#
#  Number of spaces to use per indentation level.
#  Not tabs, because predicting the tab length in a particular terminal
#  is impossible anyway.
#
[ -v MSG_INDENTATION_SPACES_PER_LEVEL ]  \
	|| declare -gx MSG_INDENTATION_SPACES_PER_LEVEL=4


 # Assembles __mi according to the current MSG_INDENTATION_LEVEL
#
mi_assemble() {
	#  Internal! No xtrace_off/on needed!
	__mi=''
	local i
	for	((	i=0;
			i < (    MSG_INDENTATION_LEVEL
			       * MSG_INDENTATION_SPACES_PER_LEVEL);
			i++
		))
	do
		__mi+=' '
	done
	#  Without this, multiline messages that occur on MSG_INDENTATION_LEVEL=0,
	#  when $__mi is empty, won’t be indented properly. ‘* ’, remember?
	[ "$__mi" ] || __mi='  '
	return 0
}
export -f  mi_assemble


 # Increments the indentation level.
#  [$1] — number of times to increment $MI_LEVEL.
#         The default is to increment by 1.
#
milinc() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local count=${1:-1}  z
	for ((z=0; z<count; z++)); do
		let '++MSG_INDENTATION_LEVEL,  1'
	done
	mi_assemble || return $?
}
export -f  milinc


 # Decrements the indentation level.
#  [$1] — number of times to decrement $MI_LEVEL.
#  The default is to decrement by 1.
#
mildec() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local count=${1:-1}  z
	if (( MSG_INDENTATION_LEVEL == 0 )); then
		warn "No need to decrease indentation, it’s on the minimum."
		print_call_stack
	else
		for ((z=0; z<count; z++)); do
			let '--MSG_INDENTATION_LEVEL,  1'
		done
		mi_assemble || return $?
	fi
	return 0
}
export -f  mildec


 # Sets the indentation level to a specified number.
#  The use of this function is discouraged. milinc, mildec and mildrop are
#  better for handling increases and drops in the message indentation level.
#  $1 – desired indentation level, 0..9999.
#
milset () {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local mi_level=${1:-}
	[[ "$mi_level" =~ ^[0-9]{1,4}$ ]] || {
		warn "Indentation level should be an integer between 0 and 9999."
		return 0
	}
	MSG_INDENTATION_LEVEL=$mi_level
	mi_assemble || return $?
}
export -f  milset


 # Removes any indentation.
#
mildrop() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	MSG_INDENTATION_LEVEL=$MSG_INDENTATION_LEVEL_UPON_ENTRANCE
	mi_assemble || return $?
}
export -f  mildrop


bahelite_xtrace_off
mi_assemble
bahelite_xtrace_on

return 0