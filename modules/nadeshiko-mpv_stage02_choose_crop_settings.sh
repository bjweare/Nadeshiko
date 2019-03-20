#  Should be sourced.

#  nadeshiko-mpv_stage02_choose_crop_settings.sh
#  Nadeshiko-mpv module to run a dialogue window where user may pick crop
#  coordinates or pick them interactively.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko-mpv.sh


choose_crop_settings() {
	declare -g predictor  crop
	local  pick  has_croptool_installer  crop_width  crop_height  \
	       crop_x  crop_y  resp_crop  resp_predictor

	#  Module function.
	[ "$(type -t run_crop_tool)" = 'function' ] || return 0
	pause_and_leave_fullscreen
	#  Module function.
	[ "$(type -t run_croptool_installer)" = 'function' ]  \
		&& has_installer=yes  \
		|| has_installer=no
	[ -v predictor ]  \
		&& predictor=on  \
		|| predictor=off

	until [ -v cropsettings_accepted ]; do
		is_crop_tool_available  \
			&& pick='on'  \
			|| pick='off'

		show_dialogue_crop_and_predictor pick="$pick"                    \
		                                 has_installer="$has_installer"  \
		                                 predictor="$predictor"          \
		                                 ${crop_width:-}                 \
		                                 ${crop_height:-}                \
		                                 ${crop_x:-}                     \
		                                 ${crop_y:-}

		IFS=$'\n' read -r -d ''  resp_crop       \
		                         resp_predictor  \
			< <(echo -e "$dialog_output\0")

		declare -p resp_crop  resp_predictor
		case "${resp_crop#crop=}" in
			nocrop)
				info 'Disabling crop.'
				unset crop
				cropsettings_accepted=t
				;;
			+([0-9]):+([0-9]):+([0-9]):+([0-9]))
				info 'Setting crop size and position.'
				orig_width=$(get_ffmpeg_attribute "$path" v width)
				orig_height=$(get_ffmpeg_attribute "$path" v height)
				[[ "$resp_crop" =~ ^crop=([0-9]+):([0-9]+):([0-9]+):([0-9]+)$ ]]
				crop_width=${BASH_REMATCH[1]}
				crop_height=${BASH_REMATCH[2]}
				crop_x=${BASH_REMATCH[3]}
				crop_y=${BASH_REMATCH[4]}
				declare -p orig_width  orig_height  crop_width  crop_height  \
				           crop_x  crop_y
				(( crop_width <= orig_width ))  \
					|| err "Crop width is larger than the video itself: W > origW."
				(( crop_height <= orig_height ))  \
					|| err "Crop height is bigger than the video itself: H > origH."
				(( crop_x <= ( orig_width - crop_width ) ))  \
					|| err "Crop Xtopleft puts crop area out of frame bounds: X + W > origW."
				(( crop_y <= ( orig_height - crop_height ) ))  \
					|| err "Crop Ytopleft puts crop area out of frame bounds: Y + H > origH."
				cropsettings_accepted=t
				;;
			pick)
				unset crop_width  crop_height  crop_x  crop_y  crop
				prepare_crop_tool  \
					|| err 'Cropping module failed at preparing crop tool.'
				run_crop_tool  \
					|| err 'Cropping module failed at running crop tool.'
				if [ -v croptool_resp_cancelled ]; then
					warn-ns 'Cropping cancelled.'
				elif [ -v croptool_resp_failed ]; then
					warn-ns 'Crop tool failed.'
				else
					crop_width=$croptool_resp_width
					crop_height=$croptool_resp_height
					crop_x=$croptool_resp_x
					crop_y=$croptool_resp_y
					crop="$crop_width:$crop_height:$crop_x:$crop_y"
				fi
				;;
			install_croptool)
				run_croptool_installer  \
					|| err 'Crop tool installer has exited with an error.'
				;;
			*)
				err "Dialog returned wrong value for crop: “$resp_crop”."
				;;
		esac

		case "${resp_predictor#predictor=}" in
			on)
				predictor=on
				;;
			off)
				predictor=off
				;;
			*)
				err "Dialog returned wrong value for predictor: “$resp_predictor”."
				;;
		esac

	done

	[ "$predictor" != on ] && unset predictor
	return 0
}


return 0