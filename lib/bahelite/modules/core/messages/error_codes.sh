#  Should be sourced.

#  error_codes.sh
#  Functions to validate custom set error codes.
#  (If you’re looking for how error codes work in general, see the comment
#   at the top of bahelite.sh and __msg() in the “messages” module.)
#  © deterenkelt 2018–2019

#  Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	cat <<-EOF  >&2
	Bahelite error on loading module ${BASH_SOURCE##*/}:
	load the core module (bahelite.sh) first.
	EOF
	return 4
}

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_ERROR_CODES_VER ] && return 0
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_ERROR_CODES_VER='1.0'


(( $# != 0 )) && {
	echo "Bahelite module “error_codes” doesn’t take arguments!"  >&2
	[ "$*" = help ]  \
		&& return 0  \
		|| return 4
}


#  See the definition of ERROR_CODES in the “messages” module.


bahelite_validate_error_code() {
	local error_code=$1
	if	[[ "$error_code" =~ ^[0-9]{1,3}$ ]]  \
		&&  ((
		            (       $error_code >= 7
		                &&  $error_code <= 125
		            )

		        ||  (       $error_code >= 166
		                &&  $error_code <= 254
		            )
		    ))
	then
		return 0
	else
		return 1
	fi
}
export -f bahelite_validate_error_code


bahelite_validate_error_codes() {
	local  key
	local  invalid_code

	[ -v ERROR_CODES ] && [ ${#ERROR_CODES[*]} -ne 0 ] && {
		for key in ${!ERROR_CODES[*]}; do
			bahelite_validate_error_code "${ERROR_CODES[key]}" || {
				echo "Bahelite error: Invalid exit code in ERROR_CODES[$key]:" >&2
				echo "should be a number in range 7…125 or 166…254 inclusively." >&2
				invalid_code=t
			}
		done
		[ -v invalid_code ] && exit 4
	}

	return 0
}


#  Validating user’s custom error codes
bahelite_validate_error_codes

return 0