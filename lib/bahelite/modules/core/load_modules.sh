#  Should be sourced.

#  load_modules.sh
#  Functions that determine, which modules have to be loaded, and load their
#  source code. Modules put the actual work in the functions and set them up
#  as “postload jobs” (there’s a separate module with the same name, that
#  calls them). However, the modules may have tiny parts of code, that is
#  executed at the time the module is loaded.
#  © deterenkelt 2018–2019

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_LOAD_MODULES_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_LOAD_MODULES_VER='1.0'


 # Array to define which modules are to be loaded
#  This array is to be defined in the main script.
#
#  Item format: BAHELITE_LOAD_MODULES=(
#                   module_name1
#                   module_name2:some_option:other_option=value:help
#               )
#  Module names are given without the “.sh” extension. Module name may be
#    followed by options, that are separated from the name (and between each
#    other) with a colon (:). If an option has a value, pass it via the equals
#    sign.
#  Every module takes option named “help”, that prints to console, which
#    arguments that module takes. After processing the “help” option of any
#    module the execution stops. Spaces and special characters are not allowed.
#  Only two modules cannot have options: this one and “checking_dependencies”.
#
# BAHELITE_LOAD_MODULES=()


 # Modules may define startup jobs as elements in this array
#
#  When modules are loaded, they mostly just define functions, and if they
#  execute any code, it’s small and defines the necessary abstracts, things,
#  that don’t depend on anything. The functions, that organise facilities,
#  *may* depend on other functions-facility-organisers. These dependencies
#  are solved after loading modules. At the end of this script the functions
#  defined in this array, are called as “startup jobs” and their dependencies
#  are resolved then.
#
#  This array is to be used and expanded ONLY by Bahelite modules.
#  Item format: “func_name” or “func_name:after=another_funcname”.
#
declare -ga BAHELITE_POSTLOAD_JOBS=()



 # Find a module file and source it, passing it options
#  from BAHELITE_LOAD_MODULES.
#
#   $1     – module name.
#  [$2..n] – module parameters.
#
bahelite_load_module() {
	local module_name="$1"

	 # The module is to be sourced with the options as they are passed to this
	#    function. There is a nuance to the “source” builtin, however. If we’d
	#    simply extract the module options as arguments 2..n, and there would
	#    be none – by default no module receives any options – then the “source”
	#    builtin would substitute for the arguments to the sourced file the
	#    arguments passed to this very function, and it would pass the module
	#    name then.
	#  The ideally safe, stable and understandable solution to this is to shift
	#    the module name out of the arguments and use the rest as the arguments
	#    for the “source” command. This way even if it would expand to nothing,
	#    it couldn’t take anything from the function arguments.
	#
	shift
	#
	#  $@ are assigned to a named variable, because actually passing "$@"
	#  to the source builtin would cover by itself the double reading of $@,
	#  that would happen there.
	#
	local module_opts=( "$@" )
	local matching_modules_list=()
	local matches_count=0
	local module_path
	local i
	local do_mildec

	[ -v BAHELITE_MODULES_ARE_VERBOSE ] && {
		local module_short_name=${module_name##*/}
		module_short_name=${module_short_name%.sh}
		[ -v BAHELITE_MODULE_${module_short_name^^}_VER ] && {
			denied "Module ${module_short_name} is already loaded."
			return 0
		}

		info "Module “$module_name”"
		milinc
		info "options: “${module_opts[*]}”."
		#  This variable should be checked instead
		#  of BAHELITE_MODULES_ARE_VERBOSE, because at some point
		#  the “verbosity” module should load. And it will so happen, that
		#  at the beginning of this function BAHELITE_MODULES_ARE_VERBOSE
		#  is not activated yet, but at the end (where we call “mildec”)
		#  it is, so controlling the indentation would be uneven.
		do_mildec=t
	}

	if [ -f "$module_name"  -a  -r "$module_name" ]; then
		module_path="$module_name"
	else
		while IFS= read -r -d ''; do
			matching_modules_list+=( "$REPLY" )
			let "matches_count++, 1"
		done < <(
		            find -L "$BAHELITE_DIR"  \
		                 -type f  \
		                 -iname "$module_name.sh"  \
		                 -print0
		        )

		(( matches_count == 0 ))  && {
			echo "Bahelite error: cannot find module “$module_name”."  >&2
			return 4
		}

		(( matches_count > 1 ))  && {
			echo "Bahelite error: ambiguous module name “$module_name”:"  >&2
			for i in "${matching_modules_list[@]}"; do
				echo "  ${i##*/}"  >&2
			done
			return 4
		}

		#  Cannot use “read” variable from above, it’s assigned an empty string.
		module_path="${matching_modules_list[0]}"
	fi

	[ -v BAHELITE_MODULES_ARE_VERBOSE ]  \
		&& info "Path: “$module_path”."

	 # As we are currently in a limited scope, the “source” command
	#  will make all declare calls local. To define global variables
	#  “declare -g” must be used in all modules!
	#
	source "$module_path"  "${module_opts[@]}"  || {
		echo
		echo "Bahelite error: cannot load module “$module_name”."  >&2
		return 4
	}

	[ -v do_mildec ] && mildec
	return 0
}
export -f bahelite_load_module


bahelite_validate_load_modules_list() {
	local job
	local name='[A-Za-z0-9_]+'    # module name
	local opt='[A-Za-z0-9_-]+'    # option for the module
	local val='[A-Za-z0-9_.-]+'   # option value

	for job in "${BAHELITE_LOAD_MODULES[@]}"; do
		[[ "$job" =~ ^$name(\:\:?$opt(\=$val)?(\:\:?$opt(\=$val)?)*)?$ ]]  || {
			cat <<-EOF  >&2
			Bahelite error: invalid item in BAHELITE_LOAD_MODULES:
			  “$job”.
			The format allows:
			  - “module_name”
			  - “module_name:option”
			  - “module_name:option1=value1;option2=value2;option3”
			  - “module_name:option1=value1:option2=value2:option3”
			Module name: [A-Za-z0-9_]+
			Option: [A-Za-z0-9_-]+
			Option value: [A-Za-z0-9_.-]+
			EOF
			return 4
		}
	done
	return 0
}


bahelite_load_modules() {
	local module_name_and_opts
	local module_name
	local module_opts
	local module_path

	#  “Outer core” modules loaded first.
	bahelite_load_module 'util_overrides' || exit $?
	bahelite_load_module 'messages' || exit $?
	bahelite_load_module 'verbosity' || exit $?
	#  Once the “verbosity” module is loaded, we can report what we do
	#  to the console.
	[ -v BAHELITE_MODULES_ARE_VERBOSE ] && {
		info "Bahelite: loading modules."
		milinc
	}
	bahelite_load_module 'error_handling' || exit $?
	bahelite_load_module 'postload_jobs' || exit $?
	bahelite_load_module 'tmpdir' || exit $?

	#  Loading the rest.
	[ -v BAHELITE_LOAD_MODULES ] && {
		bahelite_validate_load_modules_list
		for module_name_plus_opts in "${BAHELITE_LOAD_MODULES[@]}"; do
			if [[ "$module_name_plus_opts" =~ ^([^\:]+)\:\:?(.+)$ ]]; then
				module_name="${BASH_REMATCH[1]}"
				bahelite_extglob_on
				module_opts=( ${BASH_REMATCH[2]//\:?(\:)/ } )
				bahelite_extglob_off
			else
				module_name="$module_name_plus_opts"
				module_opts=()
			fi
			bahelite_load_module $module_name "${module_opts[@]}"  || exit $?
		done
	}
	[ -v BAHELITE_MODULES_ARE_VERBOSE ] && mildec
	return 0
}


return 0