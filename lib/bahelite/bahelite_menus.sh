# Should be sourced.

#  bahelite_menus.sh
#  Function(s) for drawing menus.
#  deterenkelt © 2018

# The benefits of using these functions over “read” and “select”:
# - with read and select you type a certain string as teh answer…
#   …and the user often mistypes it
#   …and you must place strict checking on what is typed
#   …which blows your code, so you need a helper function anyway.
#   But with Bahelite this function is ready for use and the moves
#   are reduced to keyboard arrows – one can’t answer wrong, when
#   arrows highlight one string or the other (“Yes” or “No” for example)
# - the menu changes appearance depending on the number of elements
#   to choose from:
#   1)  Pick server: "Server 1" < "Server 2"    (server 1 is highlighted)
#       <right arrow pressed>
#       Pick server: "Server 1" > "Server 2"    (now server 2 is highlighted)
#   2) Choose letter: <| S |>                   ()
#
#
#   …

# Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	echo 'Must be sourced from bahelite.sh.' >&2
	return 5
}
. "$BAHELITE_DIR/bahelite_messages.sh" || return 5

# Avoid sourcing twice
[ -v BAHELITE_MODULE_MENUS_VER ] && return 0
#  Declaring presence of this module for other modules.
BAHELITE_MODULE_MENUS_VER='1.2.2'

# It is *highly* recommended to use “set -eE” in whatever script
# you’re going to source it from.

 # When drawing a multiline menu with a cursor,
#  bahelite can use either ASCII set of characters (“poor”),
#  or unicode (“cool”). All X terminals should be able to use the “cool” set.
#  Most TTY terminals cannot use the “cool” set, however, and “poor” should
#  be chosen for them instead. One exception is jfbterm, which is a TTY-com-
#  patible terminal and allows for unicode.
#
BAHELITE_MENU_GRAPHIC='cool'

# For an X terminal or TTY with jfbterm
BAHELITE_COOL_GRAPHIC=( '“' '”' '…'   '–'   '│' '─' '∨' '∧' '◆' )
# For a regular TTY
BAHELITE_POOR_GRAPHIC=( '"' '"' '...' '-'   '|' '-' 'v' '^' '+' )

 # To clear screen each time menu() redraws its output.
#  Clearing helps to focus, while leaving old screens
#  allows to check the console output before menu() was called.
#
#BAHELITE_MENU_CLEAR_SCREEN=t


 # Shows a menu, where a selection is made with only arrows on keyboard.
#
#  TAKES
#      $1 – prompt
#      $2..n – options to choose from. The first one become the default.
#                If the default option is not the first one, it should be
#                given _with underscores_.
#              If the user must set values to options, vertical type of menu
#                allows to show values aside of the option names.
#                To pass a value for an option, add it after the option name
#                and separate from it with “---”.
#                If the option name has underscores marking it as default,
#                they surround only the option name, as usual.
#  SETS
#      CHOSEN – selected option.
#
menu-bivar() { menu --mode bivariant -- "$@"; }
menu-carousel() { menu --mode carousel -- "$@"; }
menu-list() { menu --mode list -- "$@"; }
menu() {
	xtrace_off && trap xtrace_on RETURN
	local mode  pairs  chosen_idx=0  start_idx  \
	      choice_is_confirmed  prompt \
	      options=() optvals=() option \
	      rest arrow_up=$'\e[A' arrow_right=$'\e[C' \
	      arrow_down=$'\e[B' arrow_left=$'\e[D' clear_line=$'\r\e[K' \
	      left=t right=t
	local opts=$(getopt --options m:,p,s: \
	                    --longoptions mode:,pairs,start-idx: \
	                    -n 'bahelite_menus.sh' -- "$@")
	local getopt_exit_code=$?
	[ $getopt_exit_code -ne 0 ] \
		&& err "getopt couldn’t parse options."
	eval set -- "$opts"

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
						local -n graphic=BAHELITE_${BAHELITE_MENU_GRAPHIC^^[a-z]}_GRAPHIC
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
		warn "Possible modes are:
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
	[ -v pairs -a "$mode" != list ] \
		&& err 'Pairs of keys and values work only with --mode list!'
	# [ "${OVERRIDE_DEFAULT:-}" ] && chosen_idx="$OVERRIDE_DEFAULT"

	#  Now what’s left among arguements, are the prompt and keys (and values,
	#  if --pairs was set).
	prompt="${1:-}" && shift
	if [ -v pairs ]; then
		local opts=("$@")
		for ((i=1; i<${#opts[@]}+1; i++)); do
			[ $((i % 2)) -eq 0 ] \
				&& optvals+=("${opts[i-1]}") \
				|| options+=("${opts[i-1]}");
		done
	else
		options=("$@")
	fi
	for ((i=0; i<${#options[@]}; i++)); do
		[[ "${options[i]}" =~ ^_(.+)_$ ]] && {
			# Option specified _like this_ is to be selected by default.
			[ -v start_idx ] || chosen_idx=$i
			# Erasing underscores.
			options[i]="${BASH_REMATCH[1]}"
		}
	done
	[ -v start_idx ] && {
		[ $start_idx -le $(( ${#options[@]}-1 )) ] \
			&& chosen_idx=$start_idx \
			|| err "Start index “$start_idx” shouldn’t be greater than the maximum index “${#options[@]}”."
	}
	[ $mode = bivariant ] && {
		[ $chosen_idx -eq 0 ] && right='' || left=''
	}
	(( ${#options[@]} < 2 )) \
		&& err "${FUNCNAME[0]}: needs two or more items to choose from."
	until [ -v choice_is_confirmed ]; do
		[ -v BAHELITE_MENU_CLEAR_SCREEN ] && clear
		case "$mode" in
			bivariant)
				echo -en "$MI$prompt ${left:+$__g}${options[0]}${left:+$__s <} ${right:+> $__g}${options[1]}${right:+$__s} "
				;;
			carousel)
				[ $chosen_idx -eq 0 ] && left=''
				[ $chosen_idx -eq $(( ${#options[@]} -1 )) ] && right=''
				echo -en "$prompt ${left:+$__g}<|$__s $__b${options[chosen_idx]}$__s ${right:+$__g}|>$__s "
				;;
			list)
				echo -e "\n\n/${hb}${hb}${hb} $prompt ${hb}${hb}${hb}${hb}${hb}${hb}"
				for ((i=0; i<${#options[@]}; i++)); do
					[ $i -eq $chosen_idx ] && pre="$__g${di}$__s" || {
						[ $i -eq 0 ] && pre="$__g${au}$__s" || {
							[ $i -eq $(( ${#options[@]} -1 )) ] && pre="$__g${ad}$__s" || pre="${vb}"
						}
					}
					if [ -v pairs ]; then
						eval echo -e \"$pre ${options[i]}\"\$\{${optvals[i]}:+:\ \$${optvals[i]}\}
					else
						echo -e "$pre ${options[i]}"
					fi
				done
				echo -en "${__g}Up${__s}/${__g}Dn${__s}: select parameter, ${__g}Enter${__s}: confirm. "
				;;
			esac
		read -sn1
		[ "$REPLY" = $'\e' ] && read -sn2 rest && REPLY+="$rest"
		if [ "$REPLY" ]; then
			case "$REPLY" in
				"$arrow_left"|"$arrow_down"|',')
					case "$mode" in
						bivariant) left=t right='' chosen_idx=0;;
						carousel)
							[ $chosen_idx -eq 0 ] && left='' || {
								((chosen_idx--, 1))
								right=t
							}
							;;
						*)
							[ $chosen_idx -eq $(( ${#options[@]} -1)) ] \
								|| ((chosen_idx++, 1))
							;;
					esac
					;;
				"$arrow_right"|"$arrow_up"|'.')
					case "$mode" in
						bivariant) left='' right=t chosen_idx=1;;
						carousel)
							if [ $chosen_idx -eq $(( ${#options[@]}-1)) ]; then
								right=''
							else
								((chosen_idx++, 1))
								left=t
							fi
							;;
						*)
							[ $chosen_idx -eq 0 ] || ((chosen_idx--, 1))
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

 # A wrapper over shell’s “read”.
#  Provides a prompt unified with Bahelite output – it respects current
#  indentation level and by default is coloured green, as it asks user
#  to take an action. It only
#
read() {
	xtrace_off && trap xtrace_on RETURN
	local i args=( "$@" )
	for ((i=0; i<${#args[@]}; i++)); do
		[ "${args[i]}" = -p ] && {
			[ -v args[i+1] ] \
				|| err "Prompt key is used, but no string provided."
			args[i+1]="$(echo -en "$MI${__g}${args[i+1]}${__s} ${__b}>${__s} ")"
		}
	done
	builtin read "${args[@]}"
}


return 0