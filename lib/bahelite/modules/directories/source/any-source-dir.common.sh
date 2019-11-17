#  Should be sourced.

#  any-source-dir.common.sh
#  Finds source directories in the installation and sets paths.
#  See source_directories.sh module for the details.
#  © deterenkelt 2019

#  Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	cat <<-EOF  >&2
	Bahelite error on loading module ${BASH_SOURCE##*/}:
	load the core module (bahelite.sh) first.
	EOF
	return 4
}

#  Get the name of the module in whose stead to act
module_name="${BASH_SOURCE##*/}"
module_name="${module_name%.sh}"

 # When Bahelite modules are loaded not selectively, this module
#  might be loaded too – as is, – but that must be avoided.
#
[ "$module_name" = any-source-dir.common ]  && return 0


#  Avoid sourcing this module twice
[ -v BAHELITE_MODULE_${module_name^^}_VER ] && return 0
#  Declaring presence of this module
declare -grx BAHELITE_MODULE_${module_name^^}_VER='1.0'
bahelite_load_module 'source_directories' || return $?


 # Describes what arguments this module takes (if if takes any)
#
__show_usage_any-source-dir_module() {
	cat <<-EOF  >&2
	Bahelite module “$module_name” arguments:

	subdir=custom_directory_name
	        The name of the subdirectory to be searched under system directories
	        such as /usr/(local/)lib, /usr/(local/)share etc. By default the
	        name is equal to $MYNAME_NOEXT. (Specify it when instead of one main
	        script you have a bundle, and every script in it uses the same
	        source subdirectory.)
	EOF
	return 0
}
#  No export: init stage function.
#  Throwaway function: it is called only when the execution is going to stop,
#  in case of an error or because module was called with “help” as a parameter.
#  It is okay for this function to be redefined each time the module loads.


own_subdir_name="${MY_BUNCH_NAME:-$MYNAME_NOEXT}"

for arg in "$@"; do
	case "$arg" in
		help)
			__show_usage_any-source-dir_module
			exit 0
			;;
		'')
			;;
		subdir=*)
			own_subdir_name="${arg#subdir=}"
			;;
		*)
			__show_usage_any-source-dir_module
			err "Wrong argument “$arg” for the module “$module_name”."
	esac
done


                         #  Postload job  #

#  Now to have a postload job we essentially need to construct a function
#  with a unique name in runtime. (Unique name is necessary to have, so that
#  other modules, that depends on particular directories, might depend on
#  their respective prepare_*dir() functions.)
#
#  Bash doesn’t allow to construct functions in runtime. There’s no such
#  thing like with variables, where it’s possible to do stuff like
#      declare  my_var_number_${i}=$j
#  But we can construct the function, dump it to a sourcable shell file
#  and source that!
temp_func_file=$(
	mktemp --tmpdir=$TMPDIR  bahelite.prepare_${module_name}_func.XXX
)

cat <<EOF  >"$temp_func_file"
#  Should be sourced.

#  ${temp_func_file##*/}
#  A Bahelite postload job file. Generated by the any-source-dir.common.sh
#  module at runtime. This function is created from a template, because there
#  expected to be 6+ directories. So instead of maintaining 6 files with small
#  differences between each other, it’s more feasible to just use a template.
#  But due to Bash limitations the function below cannot be created and stored
#  from the code itself – it has to be dumped to a file and sourced. So if you
#  found this file in \$TMPDIR and think that it’s strange – nothing weird is
#  going on here.


 # Creates the requested subdirectory and its XDG parent.
#
prepare_${module_name}() {
	bahelite_xtrace_off  && trap bahelite_xtrace_on RETURN

	__set_source_dir "${module_name%dir}" "$own_subdir_name"

	return 0
}
#  No export: init stage function.
EOF
source "$temp_func_file"
#  ^ If you think this is bad, consider using eval,
#    like in e.g. this solution of an Euler problem: https://git.io/JeVqK

BAHELITE_POSTLOAD_JOBS+=( "prepare_${module_name}" )

unset  module_name  \
       own_subdir_name  \
       arg  \
       temp_func_file

return 0


