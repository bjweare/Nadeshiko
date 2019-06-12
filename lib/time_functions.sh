#  Should be sourced

#  time_functions.sh
#  Helper functions to convert time formats, subtract times etc.
#  © deterenkelt 2018
#
#  For licence see nadeshiko.sh


 # Returns 0, if the argument is a valid timestamp.
#  Examples of valid timestamps:
#           5                           = 00:00:05.000
#           5.222                       = 00:00:05.222
#        2500                           = 00:41:40.000
#        2500.07        = 2500.070      = 00:41:40.070
#        1:3            = 01:03         = 00:01:03.000
#       11:38                           =
#       11:38.642                       =
#     1:22:33                           =
#    01:22:33.444                       =
#    99:22:33                           =
#
is_valid_timestamp() {
	local ts=${1:-}  hours        minutes        seconds       mseconds
	#               /     \      /       \      /       \     /        \
	[[ "$ts" =~ ^(([0-9]{1,2}:|)([0-9]{1,2}:)|)([0-9]{1,6})(\.[0-9]{1,3}|)$ ]] \
		|| return 1
	minutes="${BASH_REMATCH[3]%:}"
	[ "$minutes" ] && {
		#  If minutes are set, they must be <=59
		(( 10#$minutes > 59 ))  && return 5
		seconds="${BASH_REMATCH[4]}"
		#  Same for the seconds.
		#  Only when mintues are not present, seconds may be >59.
		(( 10#$seconds > 59 ))  && return 5
	}
	return 0
}


 # Creates a global associative array $1 with timestamp $2 represented
#  in several formats as the keys.
#  $1 – variable name
#  $2 – timestamp
#
new_time_array() {
	local varname="${1:-}"  ts="${2:-}"
	is_valid_timestamp "$ts"  \
		|| err "$ts is not a valid timestamp."
	[ "$varname" ]  \
		|| err "Variable name shouldn’t be empty."
	#  Array must be _assigned_ a value (an empty value counts),
	#    or a record of it will be created, but it won’t be actually declared
	#    here, which will lead to it being local.
	#  Creation of an empty associative array with declare and "$varname"=()
	#    is not possible, so we just use "$varname"=. This will, however,
	#    create an empty element with index 0, which we’ll delete right away.
	declare -A -g "$varname"=   # DON’T TOUCH. IT WORKS ONLY IN THIS FORM.
	unset newarr[0]
	declare -n newarr="$varname"
	local  h  m  s  ms  ts_short  ts_short_no_ms  total_s_ms  total_s  total_ms
	#  BASH_REMATCH set in is_valid_timestamp.
	h="${BASH_REMATCH[2]%:}"
	m="${BASH_REMATCH[3]%:}"
	s="${BASH_REMATCH[4]}"
	#  Leading zeroes switch arithmetic in bash to octal numbers,
	#  so where we can’t know the leading zeroes are removed, we have
	#  to use “10#” prefix to indicate, that a number is decimal.
	(( 10#$s > 59 )) && {
		 h=$((  10#$s / 3600 ))
		 m=$(( (10#$s - 10#$h*3600) /60 ))
		 s=$(( (10#$s - 10#$h*3600 - 10#$m*60 ) ))
	}
	ms="${BASH_REMATCH[5]#\.}"
	# Guarantee, that HH MM SS are two digit numbers here
	local time  var
	for var in h m s; do
		declare -n time=$var
		until [[ "$time" =~ ^..$ ]]; do time="0$time"; done
	done
	#  Guarantee, that milliseconds have proper zeroes and are a three
	#  digit number: “.1” should later count as 100 ms, not 1 ms.
	until [[ "$ms" =~ ^...$ ]]; do ms+='0'; done
	ts="$h:$m:$s.$ms"
	ts_short="${h#0}:${m#0}:${s#0}.${ms}"
	ts_short_no_ms="${h#0}:${m#0}:${s#0}"
	#  Here h m s ms variables must be
	#    - not empty – or we’ll be summing emptiness $((  +  +  +  )).
	#    - do not have leading zeroes – so that bash wouldn’t treat them
	#      as octal, remember?
	total_s=$((   ${h#0}*3600
	            + ${m#0}*60
	            + ${s#0}       ))
	total_s_ms="$total_s.$ms"
	total_ms=$((   ${h#0}*3600000
	             + ${m#0}*60000
	             + ${s#0}*1000
	             + ${ms##@(0|00)}  ))

	#  Timestamp in the full format, 00:00:00.000.
	#  Hours, minutes and seconds less than 10 have leading zeroes.
	#  Milliseconds are always a three-digit number.
	newarr[ts]=$ts
	#  Same as “ts”, but colons replaced with dots.
	newarr[ts_windows_friendly]=${ts//\:/\.}
	#  Same as “ts”, but milliseconds dropped.
	newarr[ts_no_ms]=${ts%.*}
	#  Same as “ts”, but the leading zeroes are removed.
	#  This is handy, when showing duration among text, and aligning
	#  digits in columns is not needed.
	newarr[ts_short]=$ts_short
	#  “ts_short”, but without milliseconds.
	newarr[ts_short_no_ms]=$ts_short_no_ms
	#  Hours, leading zeroes removed.
	newarr[h]=${h#0}
	#  Minutes, leading zeroes removed.
	newarr[m]=${m#0}
	#  Seconds, leading zeroes removed.
	newarr[s]=${s#0}
	#  Milliseconds.
	newarr[ms]=$ms
	#  Hours, minutes and seconds as total seconds with remaining milliseconds
	#  after a dot. This is a precise value.
	newarr[total_s_ms]="$total_s.$ms"
	#  Hours, minutes and seconds as total seconds.
	#    MILLISECONDS ARE STRIPPED, SECONDS ARE ROUNDED UP.
	#    DON’T USE FOR PRECISE POSITIONING.
	#  ms may have a value of “009”, so specifying decimal system.
	(( 10#$ms > 0 )) \
		&& newarr[total_s]="$((total_s+1))" \
		|| newarr[total_s]="$total_s"
	#  Hours, minutes, seconds and milliseconds combined as milliseconds.
	newarr[total_ms]=$total_ms
	return 0
}


 # Converts milliseconds to seconds.milliseconds – an acceptable format
#  for new_time_array.
#  $1 – number of milliseconds
#
total_ms_to_total_s_ms() {
	local ms="${1:-}"
	[[ "$ms" =~ ^[0-9]{1,9}$ ]]  \
		|| err "Wrong number of milliseconds: “$ms”."
	#  Total seconds.
	echo -n $(( ms / 1000 ))
	#  Dot.
	echo -n '.'
	#  Milliseconds.
	echo $(( ms - ms/1000*1000  ))
	return 0
}


 # Converts the duration as reported by mediainfo to total number of seconds,
#  that is, “3 h 44 m 55 s 687 ms” to “13496” (milliseconds are rounded up).
#  $1 – string with hours, minutes and seconds, as reported by mediainfo.
#
mediainfo_hms_to_total_s() {
	local mihms="$1" d h m s ms total_s
	[[ "$mihms" =~ ^(([0-9]{1,})d|)(([0-9]{1,2})h|)(([0-9]{1,2})mi?n?|)(([0-9]{1,2})s|)(([0-9]{1,3})ms|)$ ]]  \
		|| err "“$mihms” is not a valid mediainfo timestamp."
	d=${BASH_REMATCH[2]:-0}
	h=${BASH_REMATCH[4]:-0}
	m=${BASH_REMATCH[6]:-0}
	s=${BASH_REMATCH[8]:-0}
	ms=${BASH_REMATCH[10]:-0}
	(( ms != 0 ))  && let '++s,  1'
	total_s=$((    d * 60 * 60 * 24
	             + h * 60 * 60
	             + m * 60
	             + s                 ))
	(( total_s == 0 ))  && err 'Duration is zero.'
	echo "$total_s"
	return 0
}


return 0