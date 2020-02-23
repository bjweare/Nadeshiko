#  Should be sourced.

#  misc.sh
#  Miscellaneous helper functions.
#  © deterenkelt 2018–2019

#  Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	cat <<-EOF  >&2
	Bahelite error on loading module ${BASH_SOURCE##*/}:
	load the core module (bahelite.sh) first.
	EOF
	return 4
}

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_MISC_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_MISC_VER='1.15'

BAHELITE_INTERNALLY_REQUIRED_UTILS+=(
	pgrep   # (procps) Single process check.
#	wc      # (coreutils) Single process check.
#	shuf    # (coreutils) For random(), it works better than $RANDOM.
	bc      # (bc) Verifying numbers.
)
BAHELITE_INTERNALLY_REQUIRED_UTILS_HINTS+=(
	[pgrep]='pgrep is a part of procps-ng.
	http://procps-ng.sourceforge.net/
	https://gitlab.com/procps-ng/procps'
)

(( $# != 0 )) && {
	echo "Bahelite module “misc” doesn’t take arguments!"  >&2
	[ "$*" = help ]  \
		&& return 0  \
		|| return 4
}


 # Returns 0, if variable passed by name contains a value, that can be treated
#  as “positive” and returns 1, if the value can be treated as “negative”.
#  Triggers an error, if the value cannot be treated as either.
#  $1  – variable name.
#
is_true() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local varname="${1:-}"
	__varname_exists "$varname"
	declare -n varval="$varname"
	if [[ "$varval" =~ ^(y|Y|[Yy]es|1|t|T|[Tt]rue|[Oo]n|[Ee]nable[d])$ ]]; then
		return 0
	elif [[ "$varval" =~ ^(n|N|[Nn]o|0|f|F|[Ff]alse|[Oo]ff|[Dd]isable[d])$ ]]; then
		if [ ${FUNCNAME[1]} = is_bool ]; then
			unset $varname
			return 0
		else
			return 1
		fi
	else
		err "Variable “$varname” must have a boolean value (0/1, on/off, yes/no),
		     but it has “$varval”."
	fi
	return 0
}
export -f  is_true
#
#
 # Same as is_true(), but unsets the variable, if its value is false, turning
#  its very existence into a boolean variable.
#
#  The purpose of this function is to verify some preset variable, e.g. from
#  a configuration file. It is done once. The variables are then should be
#  checked for existence with “[ -v varname ]”.
#
#  The other function – is_true() – is supposed to be used on any variables
#  in runtime, the variables, which maintain their either “positive” or “nega-
#  tive” value throughout the program run. They must not be unset.
#
is_bool() { is_true "$@"; }
export -f  is_bool


#  $1 – name of the variable to test.
#
is_float()            { __is_number   'float' "$1"; }
is_integer()          { __is_number 'integer' "$1"; }
#
#  $1 – number type: either “integer” or “float”.
#  $2 – name of the variable to test.
#
__is_number() {
	local number_type="$1"  varname="$2"  varval  number_pattern
	__varname_exists "$varname"
	declare -n varval="$varname"
	case $number_type in
		integer)
			number_pattern='^([0-9]+)$'
			;;
		float)
			number_pattern='^([0-9]+(\.[0-9]+|))$'
			;;
	esac

	[[ "$varval" =~ $number_pattern ]]  \
		|| err "Variable “$varname” must be an integer number, but it’s set to “$varval”."

	return 0
}
export -f  __is_number     \
               is_integer  \
               is_float



#  $1 – name of the variable to test.
#  $2 – minimum for the value.
#  $3 – maximum for the value.
#
is_float_in_range()   { __is_number_in_range   'float' "$@"; }
is_integer_in_range() { __is_number_in_range 'integer' "$@"; }
#
#  $1 – number type: either “integer” or “float”.
#  $2 – the name of the variable to test.
#  $3 – minimum for the value.
#  $4 – maximum for the value.
#
__is_number_in_range() {
	local number_type="$1"  varname="$2"  minval="$3"  maxval="$4"
	__is_number "$number_type" "$varname"
	declare -n varval="$varname"
	case $number_type in
		integer)
			number_pattern='^([0-9]+)$'
			;;
		float)
			number_pattern='^([0-9]+(\.[0-9]+|))$'
			;;
	esac

	[[ "$minval" =~ $number_pattern  &&  "$maxval" =~ $number_pattern ]]  \
		|| err "Variable “$varname” must be in range $minval <= x <= $maxval."

	if [ "$number_type" = integer ]; then
		# fast arithmetic
		if (( varval >= minval  &&  varval <= maxval )); then
			return 0
		else
			err "Variable “$varname” must be in range $minval <= x <= $maxval."
		fi
	else
		# slow bc arithmetic
		case "$(echo "$varval >= $minval && $varval <= $maxval" | bc)" in

			0)  # bc “false”
				err "Variable “$varname” must be in range $minval <= x <= $maxval."
				;;

			1)  # bc “true”
				return 0
				;;

			*)  # unknown error
				err "Couldn’t verify, that variable “$varname” conforms to the set range."
				;;
		esac
	fi
	return 0
}
export -f  __is_number_in_range     \
               is_integer_in_range  \
               is_float_in_range


#  $1 – name of the variable to test.
#  $2 – PCRE-style pattern to match the unit.
#
is_float_with_unit()                 { __is_number_with_unit     'with_unit'   'float' "$@"; }
is_integer_with_unit()               { __is_number_with_unit     'with_unit' 'integer' "$@"; }
is_float_with_unit_or_without_it()   { __is_number_with_unit 'or_without_it'   'float' "$@"; }
is_integer_with_unit_or_without_it() { __is_number_with_unit 'or_without_it' 'integer' "$@"; }
#
#  $1 – name of the variable to test.
#  $2 – minimum for the value.
#  $3 – maximum for the value.
#  $4 – PCRE-style pattern to match the unit.
#
is_float_in_range_with_unit()                 { __is_number_with_unit     'with_unit'   'float' "$@"; }
is_integer_in_range_with_unit()               { __is_number_with_unit     'with_unit' 'integer' "$@"; }
is_float_in_range_with_unit_or_without_it()   { __is_number_with_unit 'or_without_it'   'float' "$@"; }
is_integer_in_range_with_unit_or_without_it() { __is_number_with_unit 'or_without_it' 'integer' "$@"; }
#
#  $1  – possible values: “with_unit”,  “or_without_unit”
#  $2  – number type: either “integer” or “float”
#  $3  – name of the varaible to test
# [$4] – minimal value
# [$5] – maximal value
#  $6  – PCRE-style unit pattern
#
__is_number_with_unit() {
	local may_be_without_unit  varname  unit_pattern  minval  maxval  varval  \
	      proto_number  use_range  errors
	[ "$1" = 'or_without_it' ]  \
		&& may_be_without_unit=t
	number_type="$2"

	if (( $# == 4 )); then
		varname="$3"  unit_pattern="$4"

	elif (( $# == 6 )); then
		varname="$3" minval="$4" maxval="$5" unit_pattern="$6"
		use_range=t

	else
		err "Invalid arguments: “$@”"
	fi

	__varname_exists "$varname"
	declare -n varval=$varname

	[[ "$varval" =~ ^([0-9]+(\.[0-9]+|))(\ *$unit_pattern${may_be_without_unit:+|})$ ]]  \
		|| errors=t
	proto_number="${BASH_REMATCH[1]}"


	if [ -v use_range ]; then
		(is_${number_type}_in_range "proto_number" "$minval" "$maxval")  \
			|| errors=t
	else
		(is_${number_type} "proto_number")  \
			|| errors=t
	fi

	[ -v errors ]  \
		&& err "Variable $varname must be an integer with${may_be_without_unit:+ or without} unit
		        (unit pattern is “$unit_pattern”), but it was set to “$varval”."
	return 0
}
export -f  __is_number_with_unit                           \
               is_float_with_unit                          \
               is_integer_with_unit                        \
               is_float_with_unit_or_without_it            \
               is_integer_with_unit_or_without_it          \
               is_float_in_range_with_unit                 \
               is_integer_in_range_with_unit               \
               is_float_in_range_with_unit_or_without_it   \
               is_integer_in_range_with_unit_or_without_it

is_a_readable_file() { __is_a_readable_file_or_dir  file       "$1";  }
is_a_readable_dir()  { __is_a_readable_file_or_dir  directory  "$1";  }
#
#  Validates a path in RC variable
#  $1  – either “file” or “directory”.
#  $2  – variable name, whose value is to be checked.
#
__is_a_readable_file_or_dir() {
	local  file_or_dir="$1"
	local  varname="$2"

	[[ "$file_or_dir" =~ ^(file|directory)$ ]]  \
		|| err "First argument should be either “file” or “directory”."

	[ -v "$varname" ]  \
		|| err "Second argument must be a variable name, but a variable “$varname” doesn’t exist."
	declare -g $varname

	local f_or_d_key=${file_or_dir:0:1}
	local -n path=$varname

	[ -$f_or_d_key "$path"  -a  -r "$path" ] || {
		redmsg "Variable “$varname” must hold a valid path to a $file_or_dir,
		        but it holds “$path”.
		        This path either doesn’t exist or is not readable."
		err "Wrong path in “$varname”."
	}
	return 0
}
export -f  __is_a_readable_file_or_dir  \
               is_a_readable_file       \
               is_a_readable_dir


is_function() {
	[ "$(type -t "$1")" = 'function' ]
}
export -f  is_function


is_extfile() {
	[ "$(type -t "$1")" = 'file' ]
}
export -f  is_extfile


__varname_exists() {
	local varname="${1:-}"  i  called_from_readrcfile
	[ -v "$varname" ] || {
		for ((i=1; i<${FUNCNAME[*]}; i++)); do
			[ "${FUNCNAME[i]}" = read_rcfile ] && called_from_readrcfile=t
		done
		if [ -v called_from_readrcfile ]; then
			err "Config option “$varname” is requried, but it’s missing."
		else
			err "Cannot check variable “$varname” – it doesn’t exist."
		fi
	}
	return 0
}

 # Sets MYRANDOM global variable to a random number either fast or secure way
#  Secure way may take seconds to complete.
#  $1 – an integer number, which will define the range, [0..$1].
#
random-fast()   {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	__random fast "$@"
}
random-secure() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	__random secure "$@"
}
#
 # Generic function
#  $1 – mode, either “fast” or “secure”
#  $2 – an integer number, which will define the range, [0..$1].
#
__random() {
	#  Internal! No need for xtrace_off/on.
	declare -gx MYRANDOM
	local mode="${1:-}" max_number="${2:-}"

	case "$mode" in
		fast)    random_source='/dev/urandom';;
		secure)  random_source='/dev/random';;
		*)  err 'Random source must be set to either “fast” or “secure”.'
	esac
	[ -r "$random_source" ] \
		|| err "Random source file $random_source is not a readable file."

	[[ "$max_number" =~ ^[0-9]+$ ]] \
		|| err "The max. number is not specified, got “$max_number”."

	 # $RANDOM is too bad to use even when security is not a concern,
	#  because its seed works bad in containers, and 9/10 times returns
	#  the same value, if you call $RANDOM with equal time spans of one hour.
	#
	#  MYRANDOM will be set to a number between 0 and $max_number inclusively.
	#
	MYRANDOM=$(shuf --random-source=$random_source -r -n 1 -i 0-$max_number)
	return 0
}
export -f  __random  \
               random-fast  \
               random-secure


 # Removes or replaces characters, that are forbidden in Windows™ filenames.
#  $1 – a string, in which the characters have to be replaced.
#  Returns a new string to stdout.
#
remove_windows_unfriendly_chars() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local str="${1:-}"
	str=${str//\</\(}
	str=${str//\>/\)}
	str=${str//\:/\.}
	str=${str//\"/\'}
	str=${str//\\/}
	str=${str//\|/}
	str=${str//\?/}
	str=${str//\*/}
	echo -n "$str"
	return 0
}
export -f  remove_windows_unfriendly_chars


 # Allows only one instance of the main script to run.
#
single_process_check() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local our_processes        total_processes \
	      our_processes_count  total_processes_count  our_command
	[ ${#ORIG_ARGS[*]} -eq 0 ]  \
		&& our_command="bash $MYNAME_AS_IN_DOLLARZERO"  \
		|| our_command="bash $MYNAME_AS_IN_DOLLARZERO ${ORIG_ARGS[@]}"
	our_processes=$(
		pgrep -u $USER -afx "$our_command" --session 0 --pgroup 0
	)
	total_processes=$(
		pgrep -u $USER -af  "bash $MYNAME_AS_IN_DOLLARZERO"  # sic!
	)
	our_processes_count=$(echo "$our_processes" | wc -l)
	total_processes_count=$(echo "$total_processes" | wc -l)
	(( our_processes_count < total_processes_count )) && {
		redmsg "Processes: our: $our_processes_count, total: $total_processes_count.
		        Our processes are:
		        $our_processes
		        Our and foreign processes are:
		        $total_processes"
		err 'Still running.'
	}
	return 0
}
#  No export: init stage function.


 # Expands a string like “1-5” into the range of numbers “1 2 3 4 5”.
#  $1 – string with range, format: N-N, where N is an integer.
#
expand_range() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local range="$1" expanded_range
	[[ "$range" =~ ^([0-9]+)-([0-9]+)$ ]] || {
		warn "Invalid input range for expansion: “$range”."
		return 1
	}
	seq -s ' ' ${BASH_REMATCH[1]} ${BASH_REMATCH[2]}
	return 0
}
export -f  expand_range


 # Check a number and echo either a plural string or a singular string.
#   $1  – the number to test.
#  [$2] – plural string. If unset, equals to “s”. 
#  [$3] – singular string. By default has no value (and no value is needed).
#
#  Examples
#  1. line – lines
#     echo "The file has $line_number line$(plur_sing  $line_number)."
#        line_number == 1  -->  “The file has 1 line.”
#        line_number == 2  -->  “The file has 2 lines.”
#
#  2. dummy – dummies, mouse – mice
#  echo "We’ve found $mice_count $(plur_sing  $mice_count  mice  mouse)."
#     mice_count == 1   -->  “We’ve found 1 mouse.”
#     mice_count == 2   -->  “We’ve found 2 mice.”
#
#  3. await – awaits
#  echo "$task_count task$(plur_sing  $task_count) await$(plur_sing  $task_count  '' s) your attention."
#     task_count == 1  -->  “1 task awaits your attention.”
#     task_count == 2  -->  “2 tasks await your attention.”
#
#  The name of the function is the mnemonic for the argument order. That they
#    go first plural, then singular may look anti-intuitive, but if the func-
#    tion was called sing_plur, it would add yet another problem,
#    because “plur_sing” sounds more natural.
#
#  As specifying the default plural ending “s” for the function may often seem
#    logical, though not obligatory, the form of the call with the 2nd argument
#    set and the 3rd omitted is also allowed.
#
plur_sing() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local num="$1"  plural_ending  singular_ending="${3:-}"
	(( $# >= 2 ))  \
		&& plural_ending="$2"  \
		|| plural_ending='s'
	[[ "$num" =~ ^[0-9]+$ ]] || {
		print_call_stack
		warn "${FUNCNAME[0]}: “$num” is not a number!"
	}
	#  Avoiding shell arithmetic
	#  Even in case of error in the main script, this way there’s
	#  a 50/50 chance, that the right string would be printed.
	[ "${num##0}" = '1' ]  \
		&& echo -n "$singular_ending"  \
		|| echo -n "$plural_ending"
	return 0
}
export -f  plur_sing


nth() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	local number="$1"
	[[ "$number" =~ ^[0-9]+$ ]]  \
		|| err "The argument must be a number, but “$number” was given."
	echo -n "$number"
	case $number in
		1) echo -n 'st';;
		2) echo -n 'nd';;
		3) echo -n 'rd';;
		*) echo -n 'th';;
	esac
	return 0
}
export -f nth


 # Determine bash variable type
#  Returns: “string”, “regular array”, “assoc. array”
#  $1 – variable name.
#
vartype() {
	local varname="${1:-}" varval vartype_letter
	[ -v "$varname" ] || {
		print_call_stack
		err "misc: $FUNCNAME: “$1” must be a variable name!"
	}
	declare -n varval=$varname
	vartype_letter=${varval@a}
	case "${vartype_letter:0:1}" in
		a)	echo 'regular array';;
		A)  echo 'assoc. array';;
		*)  echo 'string';;
	esac
	return 0
}



return 0