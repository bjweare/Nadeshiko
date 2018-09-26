# Should be sourced.

#  bahelite.sh
#  BAsh HElper LIbrary – To Everyone!
#  ――――――――――――――――――――――――――――――――――
#  deterenkelt © 2018
#  https://github.com/deterenkelt/Bahelite
#
#  This work is based on the Bash Helper Library for Large Scripts,
#  that I’ve been initially developing for Lifestream LLC in 2016. The old
#  code of BHLLS can be found at https://github.com/deterenkelt/bhlls.

#  This program is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published
#  by the Free Software Foundation; either version 3 of the License,
#  or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but without any warranty; without even the implied warranty
#  of merchantability or fitness for a particular purpose.
#  See the GNU General Public License for more details.


#  Bahelite doesn’t enable or disable any shell options, leaving it
#  to the programmer to set the appropriate ones. Bahelite will only tempo-
#  rarely enable or disable them as needed for its internal functions.

 # bash >= 4.3 for declare -n.
#  bash >= 4.4 for the fixed typeset -p behaviour.
#
if  [ ${BASH_VERSINFO[0]:-0} -eq 4  -a  ${BASH_VERSINFO[1]:-0} -le 3 ] \
	|| [ ${BASH_VERSINFO[0]:-0} -le 3 ]
then
	echo -e "Bahelite error: bash v4.4 or higher required." >&2
	# so it would work for both sourced and executed scripts
	return 3 2>/dev/null ||	exit 3
fi

 # Scripts usually shouldn’t be sourced. And so that your main script wouldn’t
#  be sourced by an accident, Bahelite checks, that the main script is called
#  as an executable. Set BAHELITE_LET_MAIN_SCRIPT_BE_SOURCED to skip this.
#
[ ! -v BAHELITE_LET_MAIN_SCRIPT_BE_SOURCED ] && {
	[ "${BASH_SOURCE[-1]}" != "$0" ] && {
		echo -e "${BASH_SOURCE[-1]} shouldn’t be sourced." >&2
		return 4
	}
}

 # Bahelite requires util-linux >= 2.20
#
read -d '' major minor  < <(
	getopt -V \
		| sed -rn 's/^[^0-9]+([0-9]+)\.?([0-9]+)?.*/\1\n\2/p'; \
	echo -e '\0'
)
[[ "$major" =~ ^[0-9]+$  &&  "$minor" =~ ^[0-9]+$ ]] \
&&  (
		[ $major -eq 2  -a  $minor -ge 20 ] || [ $major -gt 2 ]
	) \
	|| err 'old util-linux'
unset  major minor


 # Overrides ‘set’ bash builtin to change beahviour of set ±x:
#    regular set -x output would include traponeachcommand(),
#    which is triggered by trapondebug(), which is necessary for precise
#    tracing in case of an error, but it clogs the normal trace, when user
#    calls set -x.
#  Thus there needs to be a hook on set -x that will temporarily
#    unset trap_on_debug, and bring it back on set +x.
#  There were special functions debug_on and debug_off, that
#    were intended to use instead of ‘set ±x’, but the habit of using
#    ‘set ±x’ is too strong, so this function has to be made.
#
set() {
	#  Hiding the output of the function itself.
	builtin set +x
	local command=()
	if [ "$1" = -x ]; then
		[ -v BAHELITE_TRAPONDEBUG_SET ] && {
			#  The purpose of trapondebug is to catch the line, where
			#  an error happened, better and provide a sensible trace stack.
			#  When the programmer enables xtrace, he already got the infor-
			#  mation from the trapondebug, so we disable it on the time
			#  of enabling xtrace, for it will clog the output dramatically.
			trapondebug unset
			declare -g BAHELITE_BRING_BACK_TRAPONDEBUG=t
		}
		command=(builtin set -x)
	elif [ "$1" = +x ]; then
		command=(builtin set +x)
		[ -v BAHELITE_BRING_BACK_TRAPONDEBUG ] && {
			unset BAHELITE_BRING_BACK_TRAPONDEBUG
			#  When xtrace if switched off, we can bring the trap on debug
			#  back. The desired behaviour is solely to clear the shell trace
			#  from bahelite functions.
			#  This enables functrace / set -T!
			#  Functions will inherit trap on RETURN!
			trapondebug set
		}
	else
		#  For any arguments, that are not ‘-x’ or ‘+x’,
		#    pass them as they are.
		#  This is a potential bug, as adding -x in the
		#  main ‘set’ declaration like
		#      set -xfeEu  #T
		#  or using “-o xtrace” will not use the override above.
		#  Hopefully, everyone would just use ‘set -x’ or ‘set +x’.
		command=(builtin set "$@")
	fi
	"${command[@]}"  # No “return”, to not confuse people looking at trace.
}


 # To turn off xtrace (set -x) output during the execution
#  of Bahelite own functions.
#
xtrace_off() {
	 # This prevents disabling xtrace recursively.
	#  In case some higher level function would call a lower-level function
	#  and both of them would use xtrace_off, xtrace_on would break off
	#  the hiding once it’s called inside the lover-level function, and we
	#  need to hide trace until xtrace_on would be called in the higher
	#  level function
	#[ -z "$BAHELITE_XTRACE_HIDING_KEY" ] && {
	[ ! -v BAHELITE_BRING_XTRACE_BACK ] && {
		 # If xtrace is not enabled, we have nothing to do.
		#    Calling xtrace_off by mistake may initiate unwanted hiding,
		#    which will lead to unexpected results.
		#  Essentially, this prevents calling it by a lowskilled user mistake.
		[ -o xtrace ] || return 0

		 # When set -x enables trace, the commands are prepended with ‘+’.
		#  To differentiate between user’s commands and bahelite,
		#  we temporarily change ‘+’ to ‘⋅’
		declare -g OLD_PS4="$PS4" && declare -g PS4='⋅'
		[ -v BAHELITE_HIDE_FROM_XTRACE ] && {
			builtin set +x
			declare -g BAHELITE_BRING_XTRACE_BACK=${#FUNCNAME[*]}
		}
		return 0
	}
	return 1
}
xtrace_on() {
	(( ${BAHELITE_BRING_XTRACE_BACK:-0} == ${#FUNCNAME[*]} )) && {
		unset BAHELITE_BRING_XTRACE_BACK
		builtin set -x
		#  Salty experience of learning how traps on RETURN work resulted
		#  in the following:
		#  - a trap on RETURN defined in a function persists after that func-
		#    tion quits. That means that one cannot set a trap on RETURN on
		#    entering a function and hope that it will only work once. Even
		#    though without “functrace” shell option set other functions
		#    *will not* inherit it, the source command *will*. In other words,
		#    each time you source an external file and the control returns
		#    back to the main file, the trap on RETURN triggers;
		#  - thus the trap on RETURN has a global scope anyway – and that
		#    means, that it’s possible to remove it from global scope when it
		#    completes what it needs. This way set/unset should come strictly
		#    in pairs – as needed for hiding xtrace diving into bahelite func-
		#    tions;
		#  - in order to be sure, that the return trap is executed and unset
		#    only the level, when it was set, BAHELITE_BRING_XTRACE_BACK
		#    contains the current function nesting level.
		trap '' RETURN
		#  Restoring the original PS4.
		#  Currently doesn’t work well, because xtrace off and on somehow
		#  don’t go in pairs sometimes. Needs an investigation.
		#  Most users presumably don’t alter PS4 anyway, so just set it to ‘+’.
		#declare -g PS4="${OLD_PS4:-+}"
		declare -g PS4='+'
	}
	return 0
}

 # To turn off errexit (set -e) and disable trap on ERR temporarily.
#
errexit_off() {
	[ -o errexit ] && {
		set +e
		# traponerr is set by bahelite_error_handling.sh,
		# which is an optional module.
		[ "$(type -t traponerr)" = 'function' ] && traponerr unset
		declare -g BAHELITE_BRING_BACK_ERREXIT=t
	}
	return 0
}
errexit_on() {
	[ -v BAHELITE_BRING_BACK_ERREXIT ] && {
		unset BAHELITE_BRING_BACK_ERREXIT
		set -e
		[ "$(type -t traponerr)" = 'function' ] && traponerr set
	}
	return 0
}

 # (For internal use) To turn off noglob (set -f) temporarily,
#    but bring it back to the main script’s defaults afterwards.
#  This comes handy when shell needs to use globbing like for “ls *.sh”,
#    but it is disabled by default for safety.
#
noglob_off() {
	[ -o noglob ] && {
		set +f
		declare -g BAHELITE_BRING_BACK_NOGLOB=t
	}
	return 0
}
noglob_on() {
	[ -v BAHELITE_BRING_BACK_NOGLOB ] && {
		unset BAHELITE_BRING_BACK_NOGLOB
		set -f
	}
	return 0
}


BAHELITE_VERSION="2.7"
#  $0 == -bash if the script is sourced.
[ -f "$0" ] && {
	MYNAME=${0##*/}
	MYPATH=$(realpath "$0")
	MYDIR=${MYPATH%/*}
	#  Used for desktop notification in bahelite_messages
	#  and in the title for Xdilog windows in bahelite_xdialog.sh
	[ -v MY_DESKTOP_NAME ] || {
		MY_DESKTOP_NAME="${MYNAME%.*}"
		MY_DESKTOP_NAME="${MY_DESKTOP_NAME^}"
	}
	BAHELITE_DIR=${BASH_SOURCE[0]%/*}  # The directory of this file.
}

CMDLINE="$0 $@"
ARGS=("$@")
#
#  Terminal variables
if [[ "$-" =~ ^.*i.*$ ]]; then
	TERM_COLS=$(tput cols)
else
	#  For non-interactive shells restrict the width to 80 characters,
	#  in order for the logs to not be excessively wi-i-ide.
	TERM_COLS=80
fi
TERM_LINES=$(tput lines)
#
#  X variables
[ -v DISPLAY ] && {
	read WIDTH HEIGHT width_mm < <(
		xrandr | sed -rn 's/^.* connected.* ([0-9]+)x([0-9]+).* ([0-9]+)mm x [0-9]+mm.*$/\1 \2 \3/p; T; Q1' \
		&& echo '800 600 211.6'
	)
	DPI=$(echo "scale=2; \
	            dpi=$WIDTH/$width_mm*25.4; \
	            scale=0; \
	            dpi /= 1; \
	            print dpi" \
		      | bc -q)
	unset width_mm
}

 # Script’s tempdir
#  bahelite_on_exit removes it – don’t forget anything there.
#  You may want to define BAHELITE_LOCAL_TMPDIR in order to create
#    TMPDIR not in /tmp (or TMPDIR, if it is defined beforehand), but in
#    a local directory, under ~/.cache. This is useful, when something
#    creates very large files, and your /tmp is in RAM and too small.
[ -v BAHELITE_LOCAL_TMPDIR ] && BAHELITE_LOCAL_TMPDIR="$HOME/.cache"
TMPDIR=$(mktemp --tmpdir=${BAHELITE_LOCAL_TMPDIR:-${TMPDIR:-/tmp/}} \
                -d ${MYNAME%*.sh}.XXXXXXXXXX )


 # Desktop directory
#
DESKTOP=$(which xdg-user-dir &>/dev/null && xdg-user-dir DESKTOP)
[ -d "$DESKTOP" ] || DESKTOP="$HOME"


 # Dummy logfile
#  To enable proper logging, call start_log().
LOG=/dev/null


 # XDG default directories
#  For the local subdirectories see bahelite_misc.sh and bahelite_rcfile.sh.
#
[ -v XDG_CONFIG_HOME ] || XDG_CONFIG_HOME="$HOME/.config"
[ -v XDG_CACHE_HOME ] || XDG_CACHE_HOME="$HOME/.cache"
[ -v XDG_DATA_HOME ] || XDG_DATA_HOME="$HOME/.local/share"


 # By default Bahelite turns off xtrace for its internal functions.
#  Call “unset BAHELITE_HIDE_FROM_XTRACE” after sourcing bahelite.sh
#  to view full xtrace output.
#
BAHELITE_HIDE_FROM_XTRACE=t


#  List of utilities the lack of which must trigger an error.
REQUIRED_UTILS=(
	getopt
	grep
	sed
)

noglob_off
for bahelite_module in "$BAHELITE_DIR"/bahelite_*.sh; do
	. "$bahelite_module" || return 5
done
noglob_on


[ -v BAHELITE_MODULE_MESSAGES_VER ] || {
	echo "Bahelite: cannot find bahelite_messages.sh." >&2
	return 5
}


 # Call this function in your script after extending the array above.
#
check_required_utils() {
	local  util  missing_utils
	for util in ${REQUIRED_UTILS[@]}; do
		which "$util" &>/dev/null \
			|| missing_utils="${missing_utils:+$missing_utils, }“$util”"
	done
	[ "${missing_utils:-}" ] && ierr 'no util' "$missing_utils"
	return 0
}

 # It’s a good idea to extend REQUIRED_UTILS list in your script
#  and then call check_required_utils like:
#      REQUIRED_UTILS+=( bc )
#      check_required_utils
#
check_required_utils

 # Before the main script starts, gather variables. In case of an error
#  this list would be compared to the other, created before exiting,
#  and the diff will be placed in "$LOGDIR/variables"
#
BAHELITE_STARTUP_VARLIST="$(compgen -A variable)"


return 0