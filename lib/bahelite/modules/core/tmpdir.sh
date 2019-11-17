#  Should be sourced.

#  tmpdir.sh
#  Set up a temporary directory for the main script and set TMPDIR variable.
#  The path would be /tmp/$MYNAME_NOEXT.XXXXXXXXXX
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
[ -v BAHELITE_MODULE_TMPDIR_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_TMPDIR_VER='1.0'


(( $# != 0 )) && {
	cat <<-EOF  >&2
	Bahelite module “tmpdir” doesn’t take arguments!
	(To set a predefined path, export TMPDIR variable.)
	EOF
	[ "$*" = help ]  \
		&& return 0  \
		|| return 4
}




 # This variable may be passed via environment to prevent the deletion.
#  Usually, it’s left to be in the important cases, like when the logs
#  couldn’t be written anywhere else but there (the worst case). This vari-
#  able is also set in subshells, so that the TMPDIR wouldn’t get accidentally
#  removed by an  on_exit().
#
declare -g BAHELITE_DONT_CLEAR_TMPDIR


 # Create a unique subdirectory for temporary files
#
#  It’s used by Bahelite and the main script. bahelite_on_exit() will call
#    this function’s counterpart, bahelite_delete_tmpdir() to remove the
#    directory.
#  Use TMPDIR for small files. For larger ones (1+ GiB) you should load
#    module “runtimedir”, that will create a directory under XDG_RUNTIME_DIR
#    and place the big files there.
#  You may set TMPDIR before sourcing Bahelite, this way the set directory
#    will be used instead.
#
bahelite_create_tmpdir() {
	declare -g TMPDIR

	[ -v TMPDIR ] && {
		[ -d "${TMPDIR:-}" ] || {
			echo "Bahelite warning: no such directory: “$TMPDIR”, will use /tmp." >&2
			unset TMPDIR
		}
	}
	TMPDIR=$(mktemp --tmpdir=${TMPDIR:-/tmp/}  -d $MYNAME_NOEXT.XXXXXXXXXX  )
	#  bahelite_on_exit trap shouldn’t remove TMPDIR, if the exit occurs
	#  within a subshell
	(( BASH_SUBSHELL > 0 )) && BAHELITE_DONT_CLEAR_TMPDIR=t

	declare -r TMPDIR
	return 0
}


bahelite_delete_tmpdir() {
	if    [ -d "$TMPDIR" ]  \
	   && ! mountpoint --quiet "$TMPDIR"  \
	   && [ ! -v BAHELITE_DONT_CLEAR_TMPDIR ]
	then
		#  Remove TMPDIR only after logging is done.
		rm -rf "$TMPDIR"
	fi
	return 0
}



#  Not a postpone job, because it is needed ASAP.
bahelite_create_tmpdir

return 0