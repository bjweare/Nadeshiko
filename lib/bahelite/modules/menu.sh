#  Should be sourced.

#  menu.sh
#  Function(s) for drawing menus.
#  © deterenkelt 2018–2019

 # The benefits of using these functions over “read” and “select”:
#  - with read and select you type a certain string as teh answer…
#    …and the user often mistypes it
#    …and you must place strict checking on what is typed
#    …which blows your code, so you need a helper function anyway.
#    But with Bahelite this function is ready for use and the moves
#    are reduced to keyboard arrows – one can’t answer wrong, when
#    arrows highlight one string or the other (“Yes” or “No” for example)
#  - the menu changes appearance depending on the number of elements
#    to choose from:
#    1)  Pick server: "Server 1" < "Server 2"    (server 1 is highlighted)
#        <right arrow pressed>
#        Pick server: "Server 1" > "Server 2"    (now server 2 is highlighted)
#    2) Choose letter: <| S |>                   ()
#
#    …

#  Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	cat <<-EOF  >&2
	Bahelite error on loading module ${BASH_SOURCE##*/}:
	load the core module (bahelite.sh) first.
	EOF
	return 4
}

#  Avoid sourcing twice
[ -v BAHELITE_MODULE_MENU_VER ] && return 0
bahelite_load_module 'colours' || return $?
#  Declaring presence of this module for other modules.
declare -grx BAHELITE_MODULE_MENU_VER='1.2.11'

(( $# != 0 )) && {
	echo "Bahelite module “menu” doesn’t take arguments!"  >&2
	[ "$*" = help ]  \
		&& return 0  \
		|| return 4
}


 # Characters to use for pseudographic
#  Unicode capable terminals (all terminals running in X and jfbterm on TTY)
#    are able to draw characters from the “cool” set, while the others (bare
#    TTY) better use the “poor” set.
#
declare -gax BAHELITE_MENU_COOL_GRAPHIC_STYLE=(
	'“'  '”'  '…'    '–'  '│'  '─'  '∨'  '∧'  '◆'
)
declare -gax BAHELITE_MENU_POOR_GRAPHIC_STYLE=(
	'"'  '"'  '...'  '-'  '|'  '-'  'v'  '^'  '+'
)
case "${MENU_GRAPHIC_STYLE:-}" in
	poor)
		declare -gnx MENU_GRAPHIC_STYLE='BAHELITE_MENU_POOR_GRAPHIC_STYLE'
		;;
	cool)
		;&
	*)
		declare -gnx MENU_GRAPHIC_STYLE='BAHELITE_MENU_COOL_GRAPHIC_STYLE'
		;;
esac

 # To clear screen each time menu() redraws its output.
#  Clearing helps to focus, while leaving old screens
#  allows to check the console output before menu() was called.
#
# declare -gx MENU_CLEAR_SCREEN=t


 # Shows a menu, where a selection is made with only arrows on keyboard.
#  $1    – a prompt text.
#  $2..n – options to choose from.
#          The first option in the list will become selected as default.
#            If the default option is not the first one, it should be
#            given _with underscores_.
#          If the user must set values to options, vertical type of menu
#            allows to show values aside of the option names.
#            To pass a value for an option, add it after the option name
#            and separate from it with “---”.
#          If the option name has underscores marking it as default,
#            they surround only the option name, as usual.
#
menu-bivar()    { __menu --mode bivariant -- "$@"; }
menu-carousel() { __menu --mode carousel  -- "$@"; }
menu-list()     { __menu --mode list      -- "$@"; }
__menu() {
	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
	declare -gx CHOSEN
	local mode  pairs  chosen_idx=0  start_idx  \
	      choice_is_confirmed  prompt  \
	      options=()  optvals=()  option  \
	      rest  arrow_up=$'\e[A' arrow_right=$'\e[C' \
	      arrow_down=$'\e[B'  arrow_left=$'\e[D'  clear_line=$'\r\e[K' \
	      left=t  right=t
	local opts=$(getopt --options m:,p,s: \
	                    --longoptions mode:,pairs,start-idx: \
	                    -n 'bahelite_menus.sh' -- "$@")
	local getopt_exit_code=$?
	(( getopt_exit_code != 0 ))  \
		&& err "getopt couldn’t parse options."
	eval builtin set -- "$opts"

	while true; do
		case "$1" in
			#  Selects, how the menu would look, whether it should use
			#  one line selector or a multiline list.
			-m|--mode)
				case "$2" in
					2|bi|bivariant)
						mode=bivariant
						;;
					c|carousel)
						mode=carousel
						;;
					l|list)
						mode=list
						local -n graphic='MENU_GRAPHIC_STYLE'
						local oq=${graphic[0]}  # opening quote
						local cq=${graphic[1]}  # closing quote
						local el=${graphic[2]}  # ellipsis
						local da=${graphic[3]}  # en dash
						local vb=${graphic[4]}  # vertical bar
						local hb=${graphic[5]}  # horizontal bar
						local ad=${graphic[6]}  # arrow down
						local au=${graphic[7]}  # arrow up
						local di=${graphic[8]}  # diamond
						;;
				esac
				shift 2
				;;
			#  For mode = list use each second argument as a value for the
			#  key preceding it.
			-p|--pairs)
				pairs=t
				shift
				;;
			#  Overrides the element chosen by default, even if it’s
			#  selected by _undescores_.
			-s|--start-idx)
				if [[ "$2" =~ ^[0-9]+$ ]]; then
					start_idx="$2"
					shift 2
				else
					err "Start index must be a number (0..n)."
				fi
				;;
			--)
				shift
				break
				;;
			*)
				#: err "Unknown option: “$1”."
				break
				;;
		esac
	done
	[ -v mode ] || {
		redmsg "${FUNCNAME[0]} error:
		    Possible modes are:
		      - “2”, “bi”, “bivariant” – two variants shown on one line,
		        switch flips and highlights either one or the other;
		      - “c”, “carousel” – this switch shows one variant of several
		        possible, only one is shown at a time. Two arrows are shown
		        to the left and to the right;
		      - “l”, “list” – a vertical list with a running cursor. Each line
		        represents an item. Each item may have a value: the --pairs
		        key makes each second parameter becomes the default value
		        of the key preceding it."
		err "No such mode: “$2”."
	}
	[ -v pairs  -a  "$mode" != 'list' ]  \
		&& err 'Pairs of keys and values work only with --mode list!'
	# [ "${OVERRIDE_DEFAULT:-}" ] && chosen_idx="$OVERRIDE_DEFAULT"

	#  Now what’s left among arguements, are the prompt and keys (and values,
	#  if --pairs was set).
	prompt="${1:-}" && shift
	if [ -v pairs ]; then
		local opts=("$@")
		for ((i=1; i<${#opts[@]}+1; i++)); do
			((  (i % 2) == 0  ))  \
				&& optvals+=("${opts[i-1]}")  \
				|| options+=("${opts[i-1]}")
		done
	else
		options=("$@")
	fi
	for ((i=0; i<${#options[@]}; i++)); do
		[[ "${options[i]}" =~ ^_(.+)_$ ]] && {
			#  Option specified _like this_ is to be selected by default.
			[ -v start_idx ] || chosen_idx=$i
			#  Erasing underscores.
			options[i]="${BASH_REMATCH[1]}"
		}
	done
	[ -v start_idx ] && {
		(( start_idx <= (${#options[@]}-1) ))  \
			&& chosen_idx=$start_idx \
			|| err "Start index “$start_idx” shouldn’t be greater than the maximum index “${#options[@]}”."
	}
	[ "$mode" = 'bivariant' ] && {
		(( chosen_idx == 0 ))  \
			&& right=''        \
			|| left=''
	}
	(( ${#options[@]} < 2 ))  \
		&& err "${FUNCNAME[1]}: needs two or more items to choose from."
	until [ -v choice_is_confirmed ]; do
		[ -v MENU_CLEAR_SCREEN ] && clear
		case "$mode" in
			bivariant)
				echo -en "${__mi}$prompt ${left:+$__g}${options[0]}${left:+$__s <} ${right:+> $__g}${options[1]}${right:+$__s} "
				;;
			carousel)
				(( chosen_idx == 0 )) && left=''
				(( chosen_idx == (${#options[@]} -1) )) && right=''
				echo -en "$prompt ${left:+$__g}<|${__s} ${__bri}${options[chosen_idx]}$__s ${right:+$__g}|>$__s "
				;;
			list)
				echo -e "\n\n/${hb}${hb}${hb} $prompt ${hb}${hb}${hb}${hb}${hb}${hb}"
				for ((i=0; i<${#options[@]}; i++)); do
					if (( i == chosen_idx )); then
						pre="$__g${di}$__s"
					else
						if (( i == 0 )); then
							pre="$__g${au}$__s"
						else
							(( i == (${#options[@]} -1) ))  \
								&& pre="$__g${ad}$__s"  \
								|| pre="${vb}"
						fi
					fi
					if [ -v pairs ]; then
						eval echo -e \"$pre ${options[i]}\"\$\{${optvals[i]}:+:\ \$${optvals[i]}\}
					else
						echo -e "$pre ${options[i]}"
					fi
				done
				echo -en "${__g}Up${__s}/${__g}Dn${__s}: select parameter, ${__g}Enter${__s}: confirm. "
				;;
		esac
		#  Sometimes there is something wrong with stdin, and read returns 1.
		#    Apparently, it receives EOF. SO says it’s common when we are
		#    in a loop reading something else, e.g. a file, but this happens
		#    also in some inexplainable situations.
		#  So to make it work properlyin every case, we read directly
		#    from /dev/tty.
		read -s -n1 </dev/tty
		[ "$REPLY" = $'\e' ]  \
			&& read -s -n2 rest </dev/tty  \
			&& REPLY+="$rest"
		if [ "$REPLY" ]; then
			case "$REPLY" in
				"$arrow_left"|"$arrow_down"|',')
					case "$mode" in
						bivariant)
							left=t  right=''  chosen_idx=0
							;;
						carousel)
							if (( chosen_idx == 0 )); then
								left=''
							else
								((chosen_idx--, 1))
								right=t
							fi
							;;
						*)
							(( chosen_idx != (${#options[@]} -1) ))  \
								&& ((chosen_idx++, 1))
							;;
					esac
					;;
				"$arrow_right"|"$arrow_up"|'.')
					case "$mode" in
						bivariant)
							left=''  right=t  chosen_idx=1
							;;
						carousel)
							if (( chosen_idx == (${#options[@]} -1) )); then
								right=''
							else
								((chosen_idx++, 1))
								left=t
							fi
							;;
						*)
							(( chosen_idx != 0 )) && ((chosen_idx--, 1))
							;;
					esac
					;;
			esac
			[[ "$mode" =~ ^(bivariant|carousel)$ ]] && echo -en "$clear_line"
		else
			echo
			choice_is_confirmed=t
		fi
	done
	CHOSEN=${options[chosen_idx]}
	return 0
}
export -f  __menu  \
               menu-bivar  \
               menu-carousel  \
               menu-list


 # A wrapper over shell’s “read”.
#  Provides a prompt unified with Bahelite output – it respects current
#  indentation level and by default is coloured green, as it asks user
#  to take an action.
#
#  Commented, because it causes at least one serious problem: when read is used
#  for reading a stream or file, call to the function makes an extra line
#  to appear. This can be avoided by using “builtin read” within the main
#  script, but that’d be bad.
#
# read() {
# 	bahelite_xtrace_off  &&  trap bahelite_xtrace_on RETURN
# 	local i _args=( "$@" )
# 	for ((i=0; i<${#_args[@]}; i++)); do
# 		[ "${_args[i]}" = -p ] && {
# 			[ -v _args[i+1] ] \
# 				|| err "Prompt key is used, but no string provided."
# 			_args[i+1]="$(echo -en "${__mi}${__g}${_args[i+1]}${__s} ${__bri}>${__s} ")"
# 		}
# 	done
# 	builtin read "${_args[@]}"
# 	return 0
# }



return 0