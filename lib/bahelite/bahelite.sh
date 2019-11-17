#  Should be sourced.

#  bahelite.sh
#  Bash helper library for Linux to create more robust shell scripts.
#  © deterenkelt 2018–2019
#  https://github.com/deterenkelt/Bahelite
#
#  This work is based on the Bash Helper Library for Large Scripts,
#  that the author has been initially developing for Lifestream LLC in 2016.
#  It is licensed under GPL v3.
#
 # Bahelite is free software; you can redistribute it and/or modify it
#    under the terms of the GNU General Public License as published
#    by the Free Software Foundation; either version 3 of the License,
#    or (at your option) any later version.
#  Bahelite is distributed in the hope that it will be useful, but without
#    any warranty; without even the implied warranty of merchantability
#    or fitness for a particular purpose. See the GNU General Public License
#    for more details.
#
 # Bahelite doesn’t enable or disable any shell options, it leaves to the prog-
#    rammer to choose an optimal set. Bahelite may only temporarily enable or
#    disable shell options – but only temporarily.
#  It is *highly* recommended to use “set -feEu” in the main script, and if
#    you add -T to that, thus making the line “set -feEuT”, Bahelite will be
#    able to catch more bash errors.
#

 # The exit codes:
#    1 – is not used. It is a generic code, with which main script may
#        exit, if the programmer forgets to place his exits and returns pro-
#        perly. Let these mistakes be exposed.
#    2 – is not used. Bash exits with this code, when it catches an interpre-
#        ter or a syntax error. Such errors may happen in the main script.
#    3 – Bahelite exits with this code, if the system runs an incompatible
#        version of the Bash interpreter.
#    4 – Bahelite uses this code for all internal errors, i.e. related to the
#        inner mechanics of this library, like checking for the minimal depen-
#        dencies, loading modules, on an unsolicited attempt to source the main
#        script (instead of executing it). In each case a detailed message
#        starting with “Bahelite error:” is printed to stderr.
#    5 – any error happening in the main script after Bahelite is loaded.
#        You are strongly advised to use err() from the “messages” module
#        instead of something like { echo 'An error happened!' >&2; exit 5; }.
#        To use custom error codes, use ERROR_CODES (see “messages” module).
#    6 – an abort sanctioned by the one who runs the main script. Since an
#        early quit means, that the run was not successful (as the program
#        didn’t have a chance to complete whatever it was made for), and on
#        the other hand it’s not like the program is broken (what a regular
#        error would indicate), the exit code must be distinctive from both
#        the “clear exit” with code 0 and “regular error” with code 5.
#    7–125 – free for the main script.
#    126–165 – not used by Bahelite and must not be used in the main script:
#        this range belongs to the interpreter.
#    166–254 – free for the main script.
#    255 – not used by Bahelite and must not be used in the main script:
#        this code may be triggered by more than one reason, which makes it
#        ambiguous.
#
#  Notes
#  1. Codes 5 and 6 are used only if the error_handling module is included
#    (it is included by default).
#  2. The usage of codes 1–6, 126–165, 255 is prohibited in ERROR_CODES,
#     if you decide to use it for the custom type-specific error codes.
#    (See bahelite_messages.sh for details.)



                          #  Initial checks  #

 # Require bash v4.3 for declare -n.
#          bash v4.4 for the fixed typeset -p behaviour, ${param@x} operators,
#                    SIGINT respecting builtins and interceptable by traps,
#                    BASH_SUBSHELL that is updated for process substitution.
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
if	[ ! -v BAHELITE_LET_MAIN_SCRIPT_BE_SOURCED ]  \
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
#
 # env in shebang will not recognise -i, so an internal respawn is needed
#  in order to run the script in a clean environment. Be aware, env -i
#  literally WIPES the environment – you won’t find $HOME or $USER any more.
#
if [ -v BAHELITE_TOTAL_ENV_CLEAN ]; then
	[ ! -v BAHELITE_ENV_CLEANED ] && {
		exec /usr/bin/env -i BAHELITE_ENV_CLEANED=t bash "$0" "$@"
		exit $?
	}
fi
declare -r BAHELITE_VARLIST_BEFORE_STARTUP="$(compgen -A variable)"



                   #  Checking core dependencies  #

BAHELITE_DIR=${BASH_SOURCE[0]%/*}  # The directory of this file.

. "$BAHELITE_DIR/modules/core/checking_dependencies.sh"
check_core_dependencies



                        #  Global variables  #

BAHELITE_VERSION="3.0"
#  $0 == -bash if the script is sourced.
[ -f "$0" ] && {
	MYNAME=${0##*/}
	MYNAME_NOEXT=${MYNAME%.*}
	#  Sourced scripts cannot operate on the main script’s $0,
	#  as it is changed for them to “bash”.
	MYNAME_AS_IN_DOLLARZERO="$0"
	MYPATH=$(realpath --logical "$0")
	MYDIR=${MYPATH%/*}
	#  Used for desktop notifications in bahelite_messages_to_desktop.sh
	#  and in the title for dialog windows in bahelite_dialog.sh
	[ -v MY_DISPLAY_NAME ] || {
		#  Not forcing lowercase, as there may be intended
		#  caps, like in abbreviations.
		MY_DISPLAY_NAME="${MYNAME_NOEXT^}"
	}
	#  MY_BUNCH_NAME is a “common” program name, that is handy only for
	#    a suite of main scripts. When they use common CONFDIR, CACHEDIR etc.,
	#    they may set the common name in MY_BUNCH_NAME instead of specifying
	#    the custom name in “subdir” options to every module.
	#  The “common” name works as a substitute for MYNAME_NOEXT, when modules
	#    like  any-xdg-dir.common.sh  and  any-source-dir.common.sh search
	#    and set basic paths. MY_BUNCH_NAME doesn’t affect modules “tmpdir”,
	#    “rcfile”, “logging” etc. – they read, create and write files for
	#    each main script separately (but if the module uses basic directories,
	#    those are affected by the variable MY_BUNCH_NAME).
	#  This variable can be set only in the main script.
	[ -v MY_BUNCH_NAME ] && export MY_BUNCH_NAME
	ORIG_BASHPID=$BASHPID
	ORIG_PPID=$PPID
}

CMDLINE="$0 $@"

 # ARGS array is for the common use, and it may undergo changes, as the
#  main script would find necessary. A common change would happen when
#  the main script calls read_rcfile() from the rcfile module. It will read
#  a config file name (argument that ends on “.rc.sh”) and set it to the
#  RCFILE variable, then delete this item from the argument list.
#
ARGS=( "$@" )

 # ORIG_ARGS is set once and for all, it will always have the list
#  of arguments as they were passed to the program. It should be relied
#  upon instead of ARGS, when the arguments need to be shown as the user
#  provided them, witheout any (pre)processing.
#
declare -rax ORIG_ARGS=("$@")

if [ -v TERM_COLS  -a  -v TERM_LINES ]; then
	declare -x TERM_COLS
	declare -x TERM_LINES
elif [ -v COLUMNS  -a  -v LINES ]; then
	declare -nx TERM_COLS=COLUMNS
	declare -nx TERM_LINES=LINES
else
	declare -x TERM_COLS=80
	declare -x TERM_LINES=25
fi

declare -rx  MYNAME  MYNAME_NOEXT  MYNAME_AS_IN_DOLLARZERO  MYPATH  MYDIR  \
             MY_DISPLAY_NAME  BAHELITE_VERSION  BAHELITE_DIR  CMDLINE  \
             BAHELITE_LOCAL_TMPDIR  ORIG_BASHPID  ORIG_PPID

 # By default Bahelite turns off xtrace for its internal functions.
#  set BAHELITE_SHOW_UP_IN_XTRACE after sourcing bahelite.sh
#  to view full xtrace output.
#
# BAHELITE_SHOW_UP_IN_XTRACE=t



                       #  Loading modules  #

. "$BAHELITE_DIR/modules/core/load_modules.sh"
bahelite_load_modules

#  Checking modules’ dependencies.
check_required_utils



                 #  Running modules’ postload jobs  #

bahelite_validate_postload_jobs "${BAHELITE_POSTLOAD_JOBS[@]}"

bahelite_run_postload_jobs "${BAHELITE_POSTLOAD_JOBS[@]}"



 # Before the main script starts, gather variables. In case of an error
#  this list would be compared to the other, created before exiting,
#  and the diff will be placed in "$LOGDIR/variables"
#
declare -r BAHELITE_VARLIST_AFTER_STARTUP="$(compgen -A variable)"

return 0