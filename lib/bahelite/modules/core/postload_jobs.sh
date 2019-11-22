#  Should be sourced.

#  postload_jobs.sh
#  Validate and run the functions (aka jobs), that modules have set up to
#  run after everything is loaded (that is, after all the source code of the
#  modules is loaded). See “load_modules” module for the details.
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
[ -v BAHELITE_MODULE_POSTLOAD_JOBS_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_POSTLOAD_JOBS_VER='1.0.1'


#  BAHELITE_POSTLOAD_JOBS is defined in the “load_modules” module, as it has
#  to be defined before the other modules would start to extend it.


(( $# != 0 )) && {
	echo "Bahelite module “postload_jobs” doesn’t take arguments!" >&2
	[ "$*" = help ]  \
		&& return 0  \
		|| return 4
}


 # When all modules are loaded, it’s time to run their “startup jobs”.
#
#  Loading a module simply defines the code of the necessary facilities,
#  but to do actual job (to prepare a directory in $HOME or to start a log)
#  a particular function has to be called. Modules define the names of such
#  functions in the BAHELITE_POSTLOAD_JOBS array.
#
#  This function runs the jobs in the requested order and resolves their
#  dependencies (calls other functions) as needed.
#
#  $1..n – job specifications.
#
#          Job specification format is one of the following:
#          “func_name” – runs the specified Bahlite function
#          “func_name:after=another_func” – requests, that “func_name” is
#              to be called after “another_func”.
#          “func_name:after=func1,func2, … funcN” – requests that all func-
#              tions specified after the keyword “:after=” are to be executed
#              prior to executing func_name.
#
#          Uses "${BAHELITE_POSTLOAD_JOBS[@]}" for arguments.
#
bahelite_run_postload_jobs() {

	 # Job list as is.
	#
	local jobs=( "$@" )

	 # When the dependencies are being resolved, this array holds the current
	#  chain of function names. This list is used to prevent an accidental
	#  recursive dependency.
	#
	local execution_chain=()

	 # During the recursive call, the function, that resolves dependencies,
	#  adds the names of completed functions to this array. Thus on the next
	#  iteration (or when the execution returns from yet another loop) these
	#  functions – which may be required as dependencies to other, not yet
	#  resolved jobs – these functions will be known as already executed
	#  once, i.e. as a solved dependency.
	#
	local resolved_deps=()


	 # Resolves dependencies for a job and runs it.
	#
	#  Functions specified as dependencies must be loaded beforehand.
	#    The “:after=” keyword doesn’t forcibly find and load a dependency
	#    function, if it isn’t present in the scope.
	#  Remember, that modules are first loaded, and that’s only after all the
	#    source code is loaded, the actual stuff runs.
	#  Modules are responsible for preloading other modules and for the pre-
	#    sence in the scope of all functions that a module requires. Modules
	#    thus load some other modules always (as a hard dependency), and some
	#    modules-dependencies are loaded only when a a module receives a spe-
	#    cific option via BAHELITE_LOAD_MODULES. Such modules as “logging”
	#    and “rcfile” provide an example of how this is done.
	#
	#  $1 – job specification (as passed to the mother function).
	#
	__resovle_deps_and_run() {
		local jobspec="$1"
		local job_func_name=''
		local job_deps_list=()
		local dep_func

		[ -v BAHELITE_MODULES_ARE_VERBOSE ] && {
			info "Job “$jobspec”"
			milinc
		}

		if [[ "$jobspec" =~ ^([A-Za-z0-9_-]+)\:after\=(.*)$ ]]; then
			job_func_name="${BASH_REMATCH[1]}"
			job_deps_list=( ${BASH_REMATCH[2]//\,/ } )
		else
			job_func_name="$jobspec"
			job_deps_list=()
		fi

		__check_for_a_circular_dependency() {
			local new_job="$1"
			local funcname

			for funcname in "${execution_chain[@]}"; do
				[ "$funcname" = "$new_job" ] && {
					err "Bahelite error: circular dependency in postload jobs.
					     $(for chain_el in "${execution_chain[@]}"; do
					           echo -n "$chain_el —< "
					       done)$new_job"
				}
			done

			return 0
		}

		__is_among_complete() {
			local current_job_or_dep_funcname="$1"
			local funcname

			for funcname in "${resolved_deps[@]}"; do
				[ "$funcname" = "$current_job_or_dep_funcname" ] && {
					[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
						&& info "$funcname(): already complete!"
					return 0
				}
			done

			return 1
		}

		__is_itself_a_job_with_deps() {
			local current_dep_funcname="$1"
			local job_spec

			for job_spec in "${jobs[@]}"; do
				[[ "$job_spec" =~ ^$current_dep_funcname\:after\=.*$ ]]  \
					&& return 0
			done

			return 1
		}

		__find_jobspec_by_funcname() {
			local current_dep_funcname="$1"
			local job_spec

			for job_spec in "${jobs[@]}"; do
				[[ "$job_spec" =~ ^$current_dep_funcname(\:after\=.*)?$ ]]  \
					&& echo "${BASH_REMATCH[0]}"
			done

			return 0
		}

		__is_among_complete "$job_func_name"  && return 0

		__check_for_a_circular_dependency "$job_func_name"
		execution_chain+=( "$job_func_name" )

		[ -v BAHELITE_MODULES_ARE_VERBOSE ]  && {
			info "Resolving dependencies…"
			milinc
		}

		for dep_func in "${job_deps_list[@]}"; do
			__is_among_complete "$dep_func" || {
				if __is_itself_a_job_with_deps "$dep_func"; then
					__resolve_deps_and_run "$(__find_jobspec_by_funcname "$dep_func")"
				else
					[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
						&& info "Running $dep_func()…"
					$dep_func
					[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
						&& info "Postload dependency “$dep_func” is solved."
					resolved_deps+=( "$dep_func" )
				fi
			}
		done

		[ -v BAHELITE_MODULES_ARE_VERBOSE ] && {
			info "All dependencies resolved!"
			mildec
			info "Running $job_func_name()…"
			milinc
		}

		$job_func_name

		[ -v BAHELITE_MODULES_ARE_VERBOSE ] && {
			mildec
			local jobtype
			[ "${FUNCNAME[1]}" = 'bahelite_run_postload_jobs' ]  \
				&& job_or_subjob='job'  \
				|| job_or_subjob='subjob'
			info "Postload $job_or_subjob “$job_func_name” is complete."
			mildec
			echo
		}

		resolved_deps+=( "$job_func_name" )
		return 0
	}


	[ -v BAHELITE_MODULES_ARE_VERBOSE ] && {
		if (( ${#BAHELITE_POSTLOAD_JOBS[*]} == 0 )); then
			info "POSTLOAD JOBS list is empty."
		else
			info "POSTLOAD JOBS list:"
			milinc
			for postload_job in "${BAHELITE_POSTLOAD_JOBS[@]}"; do
				msg "$postload_job"
			done
			mildec
		fi
	}

	(( ${#jobs[*]} > 0 )) && {
		[ -v BAHELITE_MODULES_ARE_VERBOSE ] && {
			info "Resolving dependencies of POSTLOAD JOBS list."
			milinc
		}

		local job

		for job in "${jobs[@]}"; do
			#  Start resolving deps for each job with an empty chain.
			execution_chain=()
			__resovle_deps_and_run "$job"
		done

		[ -v BAHELITE_MODULES_ARE_VERBOSE ] && mildec
	}

	return 0
}


bahelite_validate_postload_jobs() {
	local jobs=( "$@" )

	[ -v BAHELITE_MODULES_ARE_VERBOSE ] && {
		info "Validating $# specifications in BAHELITE_POSTLOAD_JOBS."
		milinc
	}

	local funcname='[A-Za-z0-9_-]+'
	local job

	for job in "${jobs[@]}"; do
		[[ "$job" =~ ^$funcname(\:after\=$funcname(\,$funcname)*)?$ ]]  \
			|| err "Bahelite error: invalid postload job specification:
			          “$job”."
	done

	[ -v BAHELITE_MODULES_ARE_VERBOSE ] && {
		info 'All is OK.'
		mildec
	}

	return 0
}


return 0