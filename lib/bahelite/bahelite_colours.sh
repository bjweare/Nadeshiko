# Should be sourced.

#  bahelite_colours.sh
#  Defines variables, that will contain colour setting combinations.
#  They can be used with echo -e, for example.

# Require bahelite.sh to be sourced first.
[ -v BAHELITE_VERSION ] || {
	echo 'Must be sourced from bahelite.sh.' >&2
	return 5
}

# Avoid sourcing twice
[ -v BAHELITE_MODULE_COLOURS_VER ] && return 0
#  Declaring presence of this module for other modules.
BAHELITE_MODULE_COLOURS_VER='1.0.2'

 # Colours for messages.
#  If you don’t use single-letter variables, better use them for colours.
#
export __bk='\e[30m'     # black
export __r='\e[31m'    # red
export __g='\e[32m'    # green
export __y='\e[33m'    # yellow
export __bl='\e[34m'    # blue
export __ma='\e[35m'    # magenta
export __cy='\e[36m'    # cyan
export __wh='\e[37m'    # white

export __s='\e[0m'     # stop
export __b='\e[1m'     # bright/bold.
export __dim='\e[2m'     # dim.
export __blink='\e[3m'     # blink (usually disabled).
export __u='\e[4m'     # underlined
export __inv='\e[7m'     # inverted fg and bg
export __hid='\e[8m'     # hidden

export __rb='\e[21m'   # reset bold/bright
export __d='\e[39m'    # default fg

export info_colour=$__g
export warn_colour=$__y
export err_colour=$__r


 # Strip colours from the string
#  Useful for when the message should go somewhere where terminal control
#  combinations wouldn’t be recognised.
#
strip_colours() {
	xtrace_off && trap xtrace_on RETURN
	local str="$1" c c_val
	for c in __bk __r __g __y __bl __ma __cy __wh __s __b __dim __u __inv \
	         __hid __rb __d; do
	    declare -n c_val=$c
	    str=${str//${c_val//\\/\\\\}/}
	done
	echo "$str"

	# Doesn’t work as good.
	#sed -r 's/[[:cntrl:]]\[[0-9]{1,3}[mKG]//g' <<<"$1"
	return 0
}


return 0