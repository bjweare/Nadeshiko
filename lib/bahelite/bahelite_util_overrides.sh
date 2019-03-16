# Should be sourced.

#  bahelite_set_overrides.sh
#  Overrides for the set builtin – for internal use within Bahelite
#  and helpers for the main script.
#  © deterenkelt 2019

#  Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	echo "Bahelite error on loading module ${BASH_SOURCE##*/}:"  >&2
	echo "load the core module (bahelite.sh) first."  >&2
	return 4
}

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_SET_OVERRIDES_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_SET_OVERRIDES_VER='1.0'



                            #  Internals  #

 # Overrides for the “set” builtin to be used internally by Bahelite.
#  A library function may need to enable or disable some shell option tem-
#    porarily, but it should restore their state (on/off) to the one, that was
#    before the call. That is, it must leave the option in the same state,
#    as it was in the main script, before call to a Bahelite internal occurred.
#    Look at this example to see, what these hooks help to avoid:
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
		declare -gx BAHELITE_BRING_BACK_ERREXIT=t
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


 # To turn noglob on and off (usually done with set -f/+f) temporarily,
#  This comes handy when shell needs to use globbing like for “ls *.sh”,
#    but it is disabled by default for safety.
#
bahelite_noglob_off() {
	#  Internal! No xtrace_off/on needed!
	[ -o noglob ] && {
		declare -gx BAHELITE_BRING_BACK_NOGLOB=t
		builtin set +f
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


 # Analogous to errexit functions. You may actually need them in your
#  main script, if you experience some weird issues related to subshells
#  or pipes.
#
bahelite_functrace_off() {
	#  Internal! No xtrace_off/on needed!
	[ -o functrace ] && {
		builtin set +T
		[ "$(type -t bahelite_toggle_ondebug_trap)" = 'function' ]  \
			&& bahelite_toggle_ondebug_trap  unset
		declare -gx BAHELITE_BRING_BACK_FUNCTRACE=t
	}
	return 0
}
bahelite_functrace_on() {
	#  Internal! No xtrace_off/on needed!
	[ -v BAHELITE_BRING_BACK_FUNCTRACE ] && {
		unset BAHELITE_BRING_BACK_FUNCTRACE
		builtin set -T
		[ "$(type -t bahelite_toggle_ondebug_trap)" = 'function' ]  \
			&& bahelite_toggle_ondebug_trap  set
	}
	return 0
}


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
		declare -gx OLD_PS4="$PS4" && declare -gx PS4='⋅'
		[ -v BAHELITE_HIDE_FROM_XTRACE ] && {
			builtin set +x
			declare -gx BAHELITE_BRING_XTRACE_BACK=${#FUNCNAME[*]}
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
		declare -gx PS4='+'
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



                            #  Facilities  #

 # Overrides user calls to ‘set’ builtin.
#
#  If the + and − confuse you (to disable noglob you use +f as if enabling it),
#  you can use these alias functions. They will leave no place for a mistake.
#
errexit_off() { set +e; }
errexit_on()  { set -e; }
functrace_off() { set +T; }
functrace_on()  { set -T; }
xtrace_off() { set +x; }
xtrace_on()  { set -x; }
noglob_off() { set +f; }
noglob_on()  { set -f; }
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
			bahelite_functrace_off
			command=(builtin set -x)
			;;
		'+x')
			bahelite_functrace_on
			command=(builtin set +x)
			;;
		'+T')
			bahelite_functrace_off
			command=(builtin set +T)
			;;
		'-T')
			bahelite_functrace_on
			command=(builtin set -T)
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


 # Overrides env to allow running a child process in a clean environment.
#  The reason why this override is needed, is that “env -i” is not good enough.
#    It runs processes in a literally *wiped* environment, that doesn’t even
#    have $HOME set any more. While what you probably want is just to have
#    an environment, identical to what you had at the start of the main script.
#    It’s only needed, that all created and exported variables would be magi-
#    cally found and unset. This override does exactly this.
#  All the variables, that appeared since Bahelite was loaded are passed to
#    env with “-u” flag to unset them. Moreover, variables preset for Bahelite
#    are remove too (it’s those variables, that can be set *before* sourcing
#    bahelite.sh to alternate its behaviour).
#
env() {
	local current_varlist  new_vars  retval
	current_varlist=$(compgen -A variable)
	new_vars=(
		$(
			echo "$BAHELITE_VARLIST_BEFORE_STARTUP"$'\n'"$current_varlist" \
				| sort | uniq -u | sort
		)
		${!BAHELITE_*} ${!MSG_*} LOGPATH LOGDIR TMPDIR
	)
	bahelite_functrace_off
	command env $(sed -r 's/\S+/-u &/g' <<<"${new_vars[*]}") "$@"
	retval=$?
	bahelite_functrace_on
	return $retval
}



export -f  bahelite_errexit_off    \
           bahelite_errexit_on     \
           bahelite_noglob_off     \
           bahelite_noglob_on      \
           bahelite_functrace_off  \
           bahelite_functrace_on   \
           bahelite_xtrace_off     \
           bahelite_xtrace_on

export -f  set  \
	           errexit_off    \
	           errexit_on     \
	           xtrace_off     \
	           xtrace_on      \
	           noglob_off     \
	           noglob_on      \
	           functrace_off  \
	           functrace_off  \
	       env

return 0