# Should be sourced.

#  bahelite.sh
#  Bash helper library for Linux to create more robust shell scripts.
#  © deterenkelt 2018–2019
#  https://github.com/deterenkelt/Bahelite
#
#  This work is based on the Bash Helper Library for Large Scripts,
#  that I’ve been initially developing for Lifestream LLC in 2016. It was
#  licensed under GPL v3.
#
 # Bahelite is free software; you can redistribute it and/or modify it
#    under the terms of the GNU General Public License as published
#    by the Free Software Foundation; either version 3 of the License,
#    or (at your option) any later version.
#  Bahelite is distributed in the hope that it will be useful, but without
#    any warranty; without even the implied warranty of merchantability
#    or fitness for a particular purpose. See the GNU General Public License
#    for more details.


 # Bahelite doesn’t enable or disable any shell options, it leaves to the prog-
#    rammer to choose an optimal set. Bahelite may only temporarely enable or
#    disable shell options – but only temporarily.
#  It is *highly* recommended to use “set -feEu” in the main script, and if
#    you add -T to that, thus making the line “set -feEuT”, Bahelite will be
#    able to catch more bash errors.
#
 # The exit codes:
#    1 – is not used. It is the generic code, with which main script may
#        exit, if the programmer forgets to place his exits and returns pro-
#        perly. Let these mistakes be exposed.
#    2 – is not used. Bash exits with this code, when it catches an interpre-
#        ter or a syntax error. Such errors may happen in the main script.
#    3 – used. Bahelite exits with this code when the version of Bash
#        is too old.
#    4 – used. Bahelite reserves this code for the errors, that occur in the
#        main module (this file). Code 4 tells about unsatisfied dependencies,
#        an attempt to source the main script (instead of executing it) or
#        that sourcing a module has failed. In every case an detailed message
#        starting with “Bahelite error:” is printed to stderr.
#  Codes from 5 and above are used only if the error_handling module is
#    included (it is included by default).
#    5 – any error happening in the main script after bahelite.sh is loaded.
#        You are strongly advised to use err() from bahelite_messages.sh
#        instead of something like { echo 'An error happened!' >&2; exit 5; }.
#    6 – an abort sanctioned by the one who runs the main script. Since an
#        early quit means, that the run was not successful (as the program
#        didn’t have a chance to complete whatever it was made for), and on
#        the other hand it’s not like the program is broken (what a regular
#        error would indicate), the exit code must be distinctive from both.
#    7–255 – are free for the main script to use, however, the codes 126–165
#        and the code 255 should be left reserved for bash. The usage of
#        codes 1–6, 126–165, 255 is prohibited in ERROR_CODES, if you decide
#        to use it for the custom type-specific error codes. (See bahelite_
#        messages.sh for details.)



 # Require bash v4.3 for declare -n.
#          bash v4.4 for the fixed typeset -p behaviour.
#
if	((    ${BASH_VERSINFO[0]:-0} <= 3
	   || (
	            ${BASH_VERSINFO[0]:-0} == 4
	        &&  ${BASH_VERSINFO[1]:-0} <  4
	      )
	))
then
	echo -e "Bahelite error: bash v4.4 or higher required." >&2
	#  so that it would work for both sourced and executed scripts
	return 3 2>/dev/null ||	exit 3
fi

 # Scripts usually shouldn’t be sourced. And so that your main script wouldn’t
#  be sourced by an accident, Bahelite checks, that the main script is called
#  as an executable. To allow the usage of Bahelite in a sourcable script,
#  set BAHELITE_LET_MAIN_SCRIPT_BE_SOURCED to any value.
#
if	[ ! -v BAHELITE_LET_MAIN_SCRIPT_BE_SOURCED ] \
	&& [ "${BASH_SOURCE[-1]}" != "$0" ]
then
	echo -e "Bahelite error: ${BASH_SOURCE[-1]} shouldn’t be sourced." >&2
	return 4
fi


                #  Cleaning the environment before start  #

 # Wipe user functions from the environment
#  This is done by default, because of the custom things, that often
#    exist in ~/.bashrc or exported from some higher, earlier shell. Being
#    supposed to only simplify the work in terminal, such functions may –
#    and often will – complicate things for a script.
#  To keep the functions exported to us in this scope, that is, the scope
#    where this very script currently execues, define BAHELITE_KEEP_ENV_FUNCS
#    variable before sourcing bahelite.sh. Keep in mind, that outer functions
#    may lead to an unexpected behaviour.
#
if [ ! -v BAHELITE_KEEP_ENV_FUNCS ]; then
	#  This wipes every function, which name doesn’t start with an underscore
	#  (those that start with “_” or “__” are internal functions mostly
	#  related to completion)
	unset -f $(declare -F | sed -rn 's/^declare\s\S+\s([^_]*+)$/\1/p')
fi
#
#  env in shebang will not recognise -i, so an internal respawn is needed
#  in order to run the script in a clean environment.
if [ -v BAHELITE_TOTAL_ENV_CLEAN ]; then
	[ ! -v BAHELITE_ENV_CLEANED ] && {
		exec /usr/bin/env -i BAHELITE_ENV_CLEANED=t bash "$0" "$@"
		exit $?
	}
fi


                    #  Checking basic dependencies  #

 # Dependency checking goes in three stages:
#  - basic dependencies (you are here). It’s those, that allow internal
#    mechanisms of Bahelite to work. Passing this stage guarantees only
#    that Bahelite has the necessary minimum to work and it can proceed
#    to loading modules and doing more complex stuff.
#  - module dependency checking. Sourcing the modules doesn’t need anything
#    but the source command – at least it shouldn’t require any outside
#    utils. The programmer is supposed to run check_required_utils (see the
#    definition below in this file) when he thinks everything would be ready,
#    and then the dependencies specified by the modules will be checked along
#    the main script dependencies.
#  - main script dependency checking. See check_required_utils below again.
#
if [ "$(type -t sed)" != 'file' ]; then
	echo 'Bahelite error: sed is not installed.' >&2
	do_exit=t

elif [ "$(type -t grep)" != 'file' ]; then
	echo 'Bahelite error: grep is not installed.' >&2
	do_exit=t

elif [ "$(type -t getopt)" != 'file' ]; then
	echo 'Bahelite error: util-linux is not installed.' >&2
	do_exit=t

elif [ "$(type -t yes)" != 'file' ]; then
	echo 'Bahelite error: coreutils is not installed.' >&2
	do_exit=t
fi
#  This is to accumulate messages, so that if more than one utility would be
#  missing, the messages would appear at once.
[ -v do_exit ] && exit 4 || unset do_exit

sed_version=$(sed --version | sed -n '1p')
grep -q 'GNU sed' <<<"$sed_version" || {
	echo 'Bahelite error: sed must be GNU sed.' >&2
	exit 4
}
grep_version=$(grep --version | sed -n '1p')
grep -q 'GNU grep' <<<"$grep_version" || {
	echo 'Bahelite error: grep must be GNU grep.' >&2
	exit 4
}

#  ex: sed (GNU sed) 4.5
if [[ "$sed_version" =~ ^sed.*\ ([0-9]+)(\.([0-9]+)|)(\.([0-9]+)|)$ ]]; then
	if	((    ${BASH_REMATCH[1]} <= 3
		   || (      ${BASH_REMATCH[1]:-0} == 4
		         &&  ${BASH_REMATCH[3]:-0} <= 2
		         &&  ${BASH_REMATCH[5]:-0} <  1
		      )
		))
	then
		echo -e "Bahelite error: sed v4.2.1 or higher required." >&2
		exit 4
	fi
else
	echo 'Bahelite error: cannot determine sed version.' >&2
	exit 4
fi

#  ex: grep (GNU grep) 3.1
if [[ "$grep_version" =~ ^grep.*\ ([0-9]+)(\.([0-9]+)|)(\.([0-9]+)|)$ ]]; then
	if	((    ${BASH_REMATCH[1]} <= 1
		   || (      ${BASH_REMATCH[1]:-0} == 2
		         &&  ${BASH_REMATCH[3]:-0} <  9
		      )
		))
	then
		echo -e "Bahelite error: grep v2.9 or higher required." >&2
		exit 4
	fi
else
	echo 'Bahelite error: cannot determine grep version.' >&2
	exit 4
fi

#  ex: getopt from util-linux 2.32
getopt_version="$(getopt --version | sed -n '1p')"
if [[ "$getopt_version" =~ ^getopt.*util-linux.*\ ([0-9]+)(\.([0-9]+)|)(\.([0-9]+)|)$ ]]; then
	if	((    ${BASH_REMATCH[1]} <= 1
		   || (      ${BASH_REMATCH[1]:-0} == 2
		         &&  ${BASH_REMATCH[3]:-0} <  20
		      )
		))
	then
		echo -e "Bahelite error: util-linux v2.20 or higher required." >&2
		exit 4
	fi
else
	echo 'Bahelite error: cannot determine util-linux version.' >&2
	exit 4
fi

#  ex: yes (GNU coreutils) 8.29
yes_version="$(yes --version | sed -n '1p')"
if [[ "$yes_version" =~ ^yes.*coreutils.*\ ([0-9]+)(\.([0-9]+)|)(\.([0-9]+)|)$ ]]; then
	if	((  ${BASH_REMATCH[1]} < 8  ))
	then
		echo -e "Bahelite error: coreutils v8.0 or higher required." >&2
		exit 4
	fi
else
	echo 'Bahelite error: cannot determine coreutils version.' >&2
	exit 4
fi

unset  sed_version  grep_version  getopt_version  yes_version




 # Overrides user calls to ‘set’ builtin.
#
set() {
	#  Hiding the output of the function itself.
	builtin set +x
	local command=()
	case "$1" in
		#  `set ±x` calls are overridden, because of a trap on DEBUG, that
		#  dramatically – but in 99.99% cases unnecessarily – increases ver-
		#  bosity. The trap is only set when “functrace” shell option is enab-
		#  led in the main script (usually with “set -T”) and “error_handling”
		#  module is sourced.
		'-x')
			[ -v BAHELITE_TRAPONDEBUG_SET ] && {
				if	[ -o functrace ]  \
					&& [ "$(type -t bahelite_toggle_ondebug_trap)" = 'function' ]
				then
					bahelite_toggle_ondebug_trap  unset
				fi
				declare -g BAHELITE_BRING_BACK_TRAPONDEBUG=t
			}
			command=(builtin set -x)
			;;
		'+x')
			[ -v BAHELITE_BRING_BACK_TRAPONDEBUG ] && {
				unset BAHELITE_BRING_BACK_TRAPONDEBUG
				if	[ -o functrace ]  \
					&& [ "$(type -t bahelite_toggle_ondebug_trap)" = 'function' ]
				then
					bahelite_toggle_ondebug_trap  set
				fi
				declare -g BAHELITE_BRING_BACK_TRAPONDEBUG=t
			}
			command=(builtin set +x)
			;;
		'-e')
			[ "$(type -t bahelite_toggle_onerror_trap)" = 'function' ]  \
				&& bahelite_toggle_onerror_trap  set
			command=(builtin set -e)
			;;
		'+e')
			[ "$(type -t bahelite_toggle_onerror_trap)" = 'function' ]  \
				&& bahelite_toggle_onerror_trap  unset
			command=(builtin set +e)
			;;
		*)
			#  For any arguments, that are not ‘-x’ or ‘+x’, pass them as they
			#  are. This is a potential bug, as adding -x in the main ‘set’
			#  declaration like
			#    set -xfeEuT
			#  or using “-o xtrace” will not use the override above. Hope-
			#  fully, everyone would just use ‘set -x’ or ‘set +x’.
			command=(builtin set "$@")
			;;
	esac
	"${command[@]}"
	#  No “return”, to minimise the output from this hook. (If people called
	#  “set -x”, they probably expect to see a trace of their code and not
	#  the trace from this function and how it returns.
}


 # Overrides for the “set” builtin to be used internally.
#  A library function may need to enable or disable some shell option tem-
#    porarily, but it should restore their state (on/off) to the one that was
#    before the call. That is, it must remember the state. To show, what
#    these hooks help to avoid, look at this example:
#
#      In the main script:                   In some library file:
#      set -f                                library_call() {
#      . . .                                     set +f
#      set +f                                    list_of_files=$(ls ./*)
#      . . .                                     set -f   # ← wrong!
#      library_call                              return 0
#      . . .    # ← library restored          }
#      . . .    #   -f already!
#      set -f
#
#  The fact that calls can go deeper than one level (i.e. one library func-
#    tion that needs a specific shell option set or unset calls another, that
#    also needs the same options set or unset), complicates the issue.
#
#
 # To turn off errexit (set -e) and disable trap on ERR temporarily.
#  bahelite_toggle_onerror_trap() is defined in bahelite_error_handling.sh,
#  which is an optional module.
#
bahelite_errexit_off() {
	#  Internal! No xtrace_off/on needed!
	[ -o errexit ] && {
		builtin set +e
		[ "$(type -t bahelite_toggle_onerror_trap)" = 'function' ]  \
			&& bahelite_toggle_onerror_trap  unset
		declare -g BAHELITE_BRING_BACK_ERREXIT=t
	}
	return 0
}
bahelite_errexit_on() {
	#  Internal! No xtrace_off/on needed!
	[ -v BAHELITE_BRING_BACK_ERREXIT ] && {
		unset BAHELITE_BRING_BACK_ERREXIT
		builtin set -e
		[ "$(type -t bahelite_toggle_onerror_trap)" = 'function' ]  \
			&& bahelite_toggle_onerror_trap  set
	}
	return 0
}
#
#
 # To turn noglob on and off (usually done with set -f/+f) temporarily,
#  This comes handy when shell needs to use globbing like for “ls *.sh”,
#    but it is disabled by default for safety.
#
bahelite_noglob_off() {
	#  Internal! No xtrace_off/on needed!
	[ -o noglob ] && {
		builtin set +f
		declare -g BAHELITE_BRING_BACK_NOGLOB=t
	}
	return 0
}
bahelite_noglob_on() {
	#  Internal! No xtrace_off/on needed!
	[ -v BAHELITE_BRING_BACK_NOGLOB ] && {
		unset BAHELITE_BRING_BACK_NOGLOB
		builtin set -f
	}
	return 0
}
#
#
 # Turn off xtrace output (usually enabled with set -x) during the execution
#    of Bahelite internal functions. Their output is normally not needed
#    in the mother script.
#  What these two functions essentially do is hiding Bahelite code from xtrace,
#    so that when “set -x” is called in the main script, only the main script
#    code is shown in the xtrace output.
#  These two functions are supposed to be used only in this expression
#      bahelite_xtrace_off  &&  trap bahelite_xtrace_on  RETURN
#    that should be the first line in an internal fucntion of the first level
#    (i.e. not the secondary helpers to them). The bahelite_xtrace_off func-
#    tion is responsible for switching xtrace off temporarily, and bahelite_
#    xtrace_on  is a trap on RETURN signal, that is set on the first call to
#    an internal function. The trap on RETURN is set only in case bahelite_
#    xtrace_off has actually changed the state of xtrace, hence the “&&” in
#    the expression. The trap returns the state of xtrace to the original
#    state, when the execution leaves internal function and return to the
#    code of the main script.
#  To show Bahelite code anyway, add “unset BAHELITE_HIDE_FROM_XTRACE” in the
#    main script someplace after sourcing bahelite.sh.
#
bahelite_xtrace_off() {
	#  This prevents disabling xtrace recursively.
	[ ! -v BAHELITE_BRING_XTRACE_BACK ] && {
		#  If xtrace is not enabled, we have nothing to do. Calling xtrace_off
		#    by mistake may initiate unwanted hiding, which will lead to unex-
		#    pected results.
		#  Essentially, this prevents calling it by a lowskilled user mistake.
		[ -o xtrace ] || return 0

		#  When set -x enables trace, the commands are prepended with ‘+’.
		#  To differentiate between main script commands and Bahelite,
		#  we temporarily change the plus ‘+’ from PS4 to a middle dot ‘⋅’.
		#  (The mnemonic is “objects further in the distance look smaller”.)
		declare -g OLD_PS4="$PS4" && declare -g PS4='⋅'
		[ -v BAHELITE_HIDE_FROM_XTRACE ] && {
			builtin set +x
			declare -g BAHELITE_BRING_XTRACE_BACK=${#FUNCNAME[*]}
		}
		return 0
	}
	return 1
}
bahelite_xtrace_on() {
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
		#  - thus the trap on RETURN has a wider scope than it seems – and this
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
#
#  ^ The functions above could be made into a single function “bahelite_set”
#  that would work analogous to the overridden “set” above, but this would be
#  less convenient:
#    - to hide xtrace output as much as possible for the internal functions,
#      it is necessary to limit down to the bare minimum extra commands before
#      the xtrace can be temporarily disabled. This makes a dedicated function
#      (like bahelite_xtrace_off) the preferrable choice, because it saves
#      commands that would need to determine, for which purpose (with which
#      parameters) that hypotetical common function “bahelite_set” is called.
#    - as xtrace functions cannot be put into one common function, this would
#      create a confusion about the role of the function that would be put
#      in the body of the “common” function (e.g. bahelite_errexit_on/off and
#      bahelite_noglob_on/off). Being implemented all in one style helps to
#      distinguish they closeness.
#  ^ That would be a mistake to merge the above functions with the overridden
#  “set”, for that would require knowledge about which of the functions in
#  “internals” and “facilities” play primary and which – secondary roles.



                        #  Initial settings  #

BAHELITE_VERSION="2.14"
#  $0 == -bash if the script is sourced.
[ -f "$0" ] && {
	MYNAME=${0##*/}
	#  Sourced scripts cannot operate on the main script’s $0,
	#  as it is changed for them to “bash”.
	MYNAME_AS_IN_DOLLARZERO="$0"
	MYPATH=$(realpath --logical "$0")
	MYDIR=${MYPATH%/*}
	#  Used for desktop notifications in bahelite_messages.sh
	#  and in the title for dialog windows in bahelite_dialog.sh
	: ${MY_DISPLAY_NAME:=${MYNAME%.*}}
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


 # The directory for temporary files
#  It’s used by Bahelite and the main script. bahelite_on_exit will remove
#    this directory, unless you set BAHELITE_DONT_CLEAR_TMPDIR or an error
#    would be caught.
#  If using /tmp is for some reason undesirable, for example, if the main
#    script creates very large files, you may want to create one under user’s
#    $HOME or somewhere else. For that, define TMPDIR=$HOME/.cache/ before
#    sourcing bahelite.sh, and TMPDIR will be set to something like
#    $HOME/.cache/my-prog.XXXXXXXXX/.
#  You can also pass TMPDIR through the environment. This is useful, when you
#    run one script from within another, and they both use Bahelite. By passing
#    TMPDIR to the inside script, you can tell it to use the same TMPDIR as
#    the main script does. With this you simplify the debugging and minimise
#    file clutter.
#
[ -v TMPDIR ] && {
	if [ -d "${TMPDIR:-}" ]; then
		#  If custom TMPDIR is provided, preserve it after exit: this is
		#  one main script chainloading another.
		[ -v BAHELITE_STARTUP_ID ] && BAHELITE_DONT_CLEAR_TMPDIR=t
	else
		echo "Bahelite warning: no such directory: “$TMPDIR”, will use /tmp." >&2
		unset TMPDIR
	fi
}
TMPDIR=$(mktemp --tmpdir=${TMPDIR:-/tmp/}  -d ${MYNAME%*.sh}.XXXXXXXXXX  )
#  bahelite_on_exit trap shouldn’t remove TMPDIR, if the exit occurs
#  within a subshell
(( BASH_SUBSHELL > 0 )) && BAHELITE_DONT_CLEAR_TMPDIR=t

declare -rx  MYNAME  MYNAME_AS_IN_DOLLARZERO  MYPATH  MYDIR  MY_DISPLAY_NAME  \
             BAHELITE_VERSION  BAHELITE_DIR  BAHELITE_LOCAL_TMPDIR  \
             CMDLINE  ARGS  TERM_COLS  TERM_LINES  TMPDIR

 # Dummy logfile
#  To enable proper logging, call start_log().
export LOG=/dev/null


 # By default Bahelite turns off xtrace for its internal functions.
#  Call “unset BAHELITE_HIDE_FROM_XTRACE” after sourcing bahelite.sh
#  to view full xtrace output.
#
export BAHELITE_HIDE_FROM_XTRACE=t


 # Lists of utilities, the lack of which must trigger an error.
#  For internal dependencies of bahelite.sh and bahelite_*.sh.
#  Long name to make it distinctive from the REQUIRED_UTILS, which is
#    the facility for the mother script.
#  Historically, this array was separated from REQUIRED_UTILS to avoid acci-
#    dental redefinition in the mother script instead of extension. It would
#    be good to set this array readonly at the end of the bahelite.sh execu-
#    tion, but it’s not possible, because modules must remain optional – 
#    the mother script may want to include additional modules after receiving
#    certain options, e.g. make checking for updates optional and include
#    bahelite_github.sh only when the option is set.
#  NO NEED TO ADD sed, grep and any of the coreutils or util-linux binaries!
#
declare -ax BAHELITE_INTERNALLY_REQUIRED_UTILS=()
#
#
 # Holds a short info on which package a missing binary may be found in.
#
declare -Ax BAHELITE_INTERNALLY_REQUIRED_UTILS_HINTS=()
#
#
 # User list for required utils
#  Ex. REQUIRED_LIST=( mimetype ffmpeg )
#  This list is initially empty to separate internally required utils from
#    the dependencies of the main script itself. If that would be a single
#    list, users could accidently wipe it with = instead of addition to it
#    with +=.
#  NO NEED TO ADD sed, grep and any of the coreutils or util-linux binaries!
#
declare -ax REQUIRED_UTILS=()
#
#
 # Holds descriptions for missing utils: which packages they can be found in,
#  which versions were used for development etc. A hint is printed when
#  a corresponding utility in REQUIRED_UTILS is not found.
#  Syntax: REQUIRED_UTILS_HINTS=( [prog1]='Prog1 can be found in Package1.' )
#  (Hints are not required, this array may be left empty.)
#
declare -Ax REQUIRED_UTILS_HINTS=()
#
#
 # In the future, add an array that would hold function names, that should
#  run sophisticated checks over the binaries, e.g. query their version,
#  or that grep is GNU grep and not BSD grep.
#declare -A REQUIRED_UTILS_CHECKFUNCS=()



                             #  Modules  #

 # Module verbosity goes first, so that the modules performing something
#  right on the source time could have default values.
#
 # When everything goes right, modules do not output anything to stdout. Only
#  in case of a potential trouble or an error they output messages. Sometimes
#  however, it would be useful to make the modules print intermediate infor-
#  mation, i.e. info messages. In regular use such messages would only unneces-
#  sarily clog the output, so they are allowed only on the increased verbosity
#  level.
#     The array below controls displaying extra info and warn messages, that
#  are normally not shown. Works per module. Redefine elements in the mother
#  script after sourcing bahelite.sh, but before calling any bahelite func-
#  tions. For example, to enable verbose messages for bahelite_rcfile.sh:
#  BAHELITE_VERBOSITY=( [rcfile]=t )
#
declare -Ax BAHELITE_VERBOSITY=(
	[bahelite]=f                  # the main module = bahelite.sh = this file.
	[colours]=f                   # bahelite_colours.sh
	[dialog]=f                    # etc.
	[directories]=f
	[error_handling]=f
	[github]=f
	[logging]=f
	[menus]=f
	[messages]=f
	[misc]=f
	[rcfile]=f
	[versioning]=f
	[x_desktop]=f
)



 # Checks whether verbosity is enabled for a certain module
#  This function is supposed to be called from within a Bahelite module,
#  i.e. bahelite_*.sh files, in the following manner:
#      bahelite_check_module_verbosity \
#          && info "Trying RC file:
#                   $rcfile"
#
bahelite_check_module_verbosity() {
	local caller_module_funcname=${FUNCNAME[1]}
	local caller_module_filename=${BASH_SOURCE[1]}
	caller_module_filename=${caller_module_filename##*/}
	caller_module_filename=${caller_module_filename%.sh}
	caller_module_filename=${caller_module_filename#bahelite_}
	[ "${BAHELITE_VERBOSITY[$caller_module_filename]}" = t ]  \
		&& return 0  \
		|| return 1
}


if [ -v BAHELITE_CHERRYPICK_MODULES ]; then
	#  Module “messages” is required.
	for module_name in messages "${BAHELITE_CHERRYPICK_MODULES[@]}"; do
		. "$BAHELITE_DIR/bahelite_$module_name.sh" || {
			echo "Bahelite error: cannot find module “$module_name”." >&2
			exit 4
		}
	done
else
	bahelite_noglob_off
	for bahelite_module in "$BAHELITE_DIR"/bahelite_*.sh; do
		. "$bahelite_module" || {
			module_name=${bahelite_module##*/}
			module_name=${module_name%.sh}
			echo "Bahelite error: cannot find module “$module_name”." >&2
			exit 4
		}
	done
	bahelite_noglob_on
fi
unset  module_name  bahelite_module


bahelite_check_module_verbosity  \
	&& info "BAHELITE_VERSION = $BAHELITE_VERSION
	         BAHELITE_DIRECTORY = $BAHELITE_DIRECTORY
	         TMPDIR = $TMPDIR
	         LOG = $LOG
	         $(  [ -v BAHELITE_LOGGING_STARTED ] \
	                 && echo "BAHELITE_LOGGING_STARTED = Yes" \
	                 || echo "BAHELITE_LOGGING_STARTED = No"
	         )
	         $(	 for bahelite_module_var in ${!BAHELITE_MODULE*}; do
	                 echo -n "$bahelite_module_var = "
	                 declare -n bahelite_module_var_val=$bahelite_module_var
	                 echo "$bahelite_module_var_val"
	             done
	         )

	         MYNAME = $MYNAME
	         MYDIR = $MYDIR"

 # Dependency checking
#  Call this function after extending REQUIRED_UTILS in the main script.
#  See also “Checking basic dependencies” above.
#
check_required_utils() {
	local  util  missing_utils req_utils=()
	req_utils=$(printf "%s\n" ${BAHELITE_INTERNALLY_REQUIRED_UTILS[@]} \
	                          ${REQUIRED_UTILS[@]} \
	                | sort -u  )
	for util in ${req_utils[@]}; do
		which "$util" &>/dev/null || {
			missing_utils="${missing_utils:+$missing_utils, }“$util”"
			if [ "${REQUIRED_UTILS_HINTS[$util]:-}" ]; then
				warn "$util was not found on this system!
				      ${REQUIRED_UTILS_HINTS[$util]}"
			elif [ "${BAHELITE_INTERNALLY_REQUIRED_UTILS_HINTS[$util]:-}" ]; then
				warn "$util was not found on this system!
				      ${BAHELITE_INTERNALLY_REQUIRED_UTILS_HINTS[$util]}"
			else
				warn "$util was not found on this system!"
			fi
		}
	done
	[ "${missing_utils:-}" ] && ierr 'no util' "$missing_utils"
	return 0
}

[ -v BAHELITE_ERROR_CODES ] && [ ${#BAHELITE_ERROR_CODES[*]} -ne 0 ] && {
	for key in ${!BAHELITE_ERROR_CODES[*]}; do
		if	[[ "${BAHELITE_ERROR_CODES[key]}" =~ ^[0-9]{1,3}$ ]]  \
			||  ((
			            (       ${BAHELITE_ERROR_CODES[key]} >= 1
			                &&  ${BAHELITE_ERROR_CODES[key]} <= 6
			            )

			        ||  (       ${BAHELITE_ERROR_CODES[key]} >= 125
			                &&  ${BAHELITE_ERROR_CODES[key]} <= 165
			            )

			        ||  ${BAHELITE_ERROR_CODES[key]} >= 255
			    ))
		then
			echo "Bahelite error: Invalid exit code in BAHELITE_ERROR_CODES[$key]:" >&2
			echo "should be a number in range 7…125 or 166…254 inclusively." >&2
			invalid_code=t
		fi
	done
	[ -v invalid_code ] && exit 4
}
unset  key  invalid_code

export -f  set  \
           bahelite_errexit_off  \
           bahelite_errexit_on  \
           bahelite_noglob_off  \
           bahelite_noglob_on  \
           bahelite_xtrace_off  \
           bahelite_xtrace_on  \
           bahelite_check_module_verbosity  \
           check_required_utils

 # The sign, that bahelite.sh successfully finished loading.
#  This variable is used in the check for chainload above, so that the chain-
#    loaded script wouldn’t accidentally wipe the TMPDIR of its main script,
#    when it executes bahelite_on_exit (if both scripts use the same TMPDIR).
#  The unique ID helps to differentiate Bahelite-specific files in a single
#    TMPDIR between several chainloaded main scripts. Currently there is only
#    one thing, that Bahelite uses tempfiles for: to handle exit from within
#    a subshell. (Solving that another way – with custom exit codes – would
#    place a requirement on the programemr to reserve exit codes in pairs,
#    from the main shell and from a subshell, which would be unobvious and
#    prone to errors.)
#
BAHELITE_STARTUP_ID=$(mktemp -u "XXXXXXXXXX")

 # Before the main script starts, gather variables. In case of an error
#  this list would be compared to the other, created before exiting,
#  and the diff will be placed in "$LOGDIR/variables"
#
BAHELITE_STARTUP_VARLIST="$(compgen -A variable)"

return 0