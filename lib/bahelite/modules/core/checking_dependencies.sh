#  Should be sourced.

#  checking_dependencies.sh
#  Functions to verify, that all external binaries required by the Bahelite
#  core and its modules are present in the system.
#  © deterenkelt 2018–2019

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_CHECKING_DEPENDENCIES_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_CHECKING_DEPENDENCIES_VER='1.0'



                 #  The 3 stages of dependency checking   #

 # 1. check_core_dependencies() verifies that before loading modules the
#       system has sed, grep, coreutils and util-linux. This is the basic
#       minimum, on which the code of the modules may count on (if the module
#       executes something at the time when it’s loaded).
#

 # 2. Module dependency checking. When the modules are loading, they may
#       define their own dependencies. For that they extend the
#       BAHELITE_INTERNALLY_REQUIRED_UTILS array. Modules pack the real work
#       into functions, and these functions may use some specific binaries.
#       In order to provide the dependency checking for all modules, their
#       source code is thus loaded and extends the array with dependencies,
#       then they are checked – this time with check_required_utils() – and
#       only then modules’ functions which were set up to run after loading,
#       actually run.
#

 # 3. Main script depencency checking. Once Bahelite has finished loading
#       modules and called all postload jobs, main script (the actual program,
#       that uses Bahelite as a library) continues to run. The programmer can
#       populate with dependencies the REQUIRED_UTILS array and when it will
#       be to verify, that all external binaries are in place, they may call
#       check_required_utils() – yes, this function again.
#     The reason why one function is used for both internal and user’s stuff,
#       is that the user may load some of the Bahelite modules depending on
#       what options were passed to their program. In other words, some Bahe-
#       lite module may be sourced after the generic procedure was completed,
#       but then, if the module is to be loaded, its dependencies must be
#       checked somehow. So instead of requiring to call two different func-
#       tions, their actions are combined in one. (There’s basically no over-
#       head, as the values of BAHELITE_INTERNALLY_REQUIRED_UTILS and
#       REQUIRED_UTILS are merged as one set.)
#


 # Lists utilities, the lack of which must trigger an error.
#  For use in bahelite.sh and all its modules. The long name is to make it
#    distinctive from the REQUIRED_UTILS, which is the facility for the main
#    script.
#  NO NEED TO ADD sed, grep and any of the coreutils
#    or util-linux binaries here!
#  Item format: BAHELITE_INTERNALLY_REQUIRED_UTILS=( date  netcat )
#
declare -ax BAHELITE_INTERNALLY_REQUIRED_UTILS=()
#
#
 # Holds a short info on which package a missing binary may be found in.
#  Item format [binaryname]="Usually found in the NNNNN package. Link: MMMMM."
#
declare -Ax BAHELITE_INTERNALLY_REQUIRED_UTILS_HINTS=()
#
#
 # User list for required utils.
#  Alike to the one above, but to be used in the main script.
#  NO NEED TO ADD sed, grep and any of the coreutils or util-linux binaries!
#  Item format: REQUIRED_UTILS=( mimetype ffmpeg )
#
declare -ax REQUIRED_UTILS=()
#
#
 # Holds descriptions for missing utils: which packages they can be found in,
#  which versions were used for development etc. A hint is printed when
#  a corresponding utility in REQUIRED_UTILS is not found.
#  Item format: same as for BAHELITE_INTERNALLY_REQUIRED_UTILS_HINTS.
#  (Hints are not required, this array may be left empty.)
#
declare -Ax REQUIRED_UTILS_HINTS=()
#
#
 # In the future, add an array that would hold function names, that should
#  run sophisticated checks over the binaries, e.g. query their version.
#
#declare -A REQUIRED_UTILS_CHECKFUNCS=()


 # Verifies, that GNU sed, GNU grep, coreutils and util-linux are available
#  for Bahelite and its modules.
#
check_core_dependencies() {
	local  do_exit
	local  sed_version
	local  grep_version
	local  getopt_version
	local  yes_version

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

	sed_version=$(sed --version | head -n1)
	grep -q 'GNU sed' <<<"$sed_version" || {
		echo 'Bahelite error: sed must be GNU sed.' >&2
		exit 4
	}
	grep_version=$(grep --version | head -n1)
	grep -q 'GNU grep' <<<"$grep_version" || {
		echo 'Bahelite error: grep must be GNU grep.' >&2
		exit 4
	}

	#  ex: sed (GNU sed) 4.5
	if [[ "$sed_version" =~ ^sed.*\ ([0-9]+)(\.([0-9]+)|)(\.([0-9]+)|)$ ]]; then

		if	((    ${BASH_REMATCH[1]} <= 3
			   ||
			      (      ${BASH_REMATCH[1]:-0} == 4
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

	return 0
}


 # Dependency checking for the time, when Bahelite modules are loaded,
#  i.e. the second and the third stages as described above.
#
check_required_utils() {
	declare -g  BAHELITE_INTERNALLY_REQUIRED_UTILS
	declare -g  BAHELITE_INTERNALLY_REQUIRED_UTILS_HINTS
	declare -g  REQUIRED_UTILS
	declare -g  REQUIRED_UTILS_HINTS

	local util
	local req_utils=()
	local missing_utils

	req_utils=$(printf "%s\n" ${BAHELITE_INTERNALLY_REQUIRED_UTILS[@]}  \
	                          ${REQUIRED_UTILS[@]}  \
	                | sort -u  )

	for util in ${req_utils[@]}; do
		which "$util" &>/dev/null || {
			missing_utils=t
			if [ "${REQUIRED_UTILS_HINTS[$util]:-}" ]; then
				redmsg "$util was not found on this system!
				       ${REQUIRED_UTILS_HINTS[$util]}"

			elif [ "${BAHELITE_INTERNALLY_REQUIRED_UTILS_HINTS[$util]:-}" ]; then
				redmsg "$util was not found on this system!
				       ${BAHELITE_INTERNALLY_REQUIRED_UTILS_HINTS[$util]}"

			else
				redmsg "$util was not found on this system!"

			fi
		}
	done
	[ -v missing_utils ]  \
		&& err 'Missing dependencies.
	            See log or console output for details.'

	#  Emptying the arrays so that the function might be called several times
	#  and once checked utilites wouldn’t be checked again.
	BAHELITE_INTERNALLY_REQUIRED_UTILS=()
	REQUIRED_UTILS=()
	return 0
}
export -f check_required_utils
#
# ^ err() and redmsg() are defined in the “messages” module, which is not
#   loaded at the time, when this module is sourced. However, as this function
#   is to be used for the first time much later than that, there’s no problem.


return 0