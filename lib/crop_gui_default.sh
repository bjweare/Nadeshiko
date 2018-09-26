#! /usr/bin/env bash

#  crop_gui_default.sh
#  Implementation of crop_gui function for Nadeshiko-mpv. Selects a rectangle
#  on a fullscreen mpv and returns the coordinates.
#  deterenkelt © 2018
#
#  For licence see nadeshiko.sh


crop_gui() {
	local ch cw cx cy

	#
	# Make sure, that mpv is running fullscreen and is on top.
	#

	select_rectangle() {
		local cropped_file
		shutter -s -C --disable_systray -e -n -o "$TMPDIR/crop_%w×%h.png"
		set +f
		cropped_file=$(ls "$TMPDIR/"crop_*×*.png)
		set -f
		if [ -f "$cropped_file" ]; then
			if [[ "${cropped_file#**/}" =~ ^crop_([0-9]+)×([0-9]+)$ ]]; then
				cw="${BASH_REMATCH[1]}"
				ch="${BASH_REMATCH[2]}"
			else
				err some err…
			fi
		else
			err some err…
		fi
		return 0
	}
	get_x_y() {
		local full_screen _x  _y
		shutter "take desktop or root 0 screenshot"
		visgrep big.png "$TMPDIR/crop_${cw}×${ch}.png"
		IFS=' ' read  _x _y < <(
			visgrep big.png small.png \
				|& sed -rn 's/^([0-9]+),([0-9]+) .*/\1 \2/p'; echo -e '\0'
		)
		if [[ "$_x" =~ ^[0-9]+$  &&  "$_y" =~ ^[0-9]+$ ]]; then
			cx=$_x
			cy=$_y
		else
			err some err…
		fi
	}
}