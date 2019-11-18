#  Should be sourced.

#  07_display_final_encoding_settings.sh
#  Nadeshiko module that displays the work of fitting the bitrates to file
#  size. It prints the optimal video bitrate, audio bitrate and the resolution
#  with which the clip is to be encoded. The latter indicates, where there
#  be a downscale, and if yes, then to which resolution.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh


display_final_encoding_settings() {
	local  encinfo
	local  vbr_c
	local  abr_c
	local  sc_c
	local  scale_text

	#  Bright (bold) white for command line overrides.
	#  Yellow for automatic scaling.
	encoding_info="Encoding with "
	[ -v forced_vbitrate ] && vbr_c="${__bri}"
	[ -v autocorrected_vbitrate ] && vbr_c="${__bri}${__y}"
	encoding_info+="${vbr_c:-}$(pretty "$vbitrate")${__s} / "
	[ -v audio ] && {
		[ -v forced_abitrate ] && abr_c="${__bri}"
		if [ -v better_abitrate_set ]; then
			abr_c="${__bri}${__g}"
		elif [ -v autocorrected_abitrate ]; then
			abr_c="${__bri}${__y}"
		fi
		encoding_info+="${abr_c:-}$(pretty "$abitrate")${__s} "
	}
	[ -v autocorrected_scale ] && sc_c="${__bri}${__y}"  scale_text="${scale}p"
	[ -v forced_scale ] && sc_c="${__bri}"  scale_text="${scale}p"
	[ -v crop ] && scale_text="at cropped resolution"
	[ -v scale_text ] || scale_text='at native resolution'
	encoding_info+="${sc_c:-}$scale_text${__s}"
	[ -v rc_default_subs -a ! -v subs ] \
		&& encoding_info+=", ${__bri}nosubs${__s}"
	[ ! -v rc_default_subs -a -v subs ] \
		&& encoding_info+=", ${__bri}subs${__s}"
	[ -v rc_default_audio -a ! -v audio ] \
		&& encoding_info+=", ${__bri}noaudio${__s}"
	[ ! -v rc_default_audio -a -v subs ] \
		&& encoding_info+=", ${__bri}audio${__s}"
	encoding_info+='.'
	info  "$encoding_info"
	return 0
}


return 0