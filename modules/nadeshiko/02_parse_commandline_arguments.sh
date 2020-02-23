#  Should be sourced.

#  02_parse_commandline_arguments.sh
#  Nadeshiko module to read arguments passed via command line and assign
#  them to variables.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh



 # Assigns start time, stop time, source video file
#  and other stuff from command line parameters.
#
parse_args() {
	declare -gA  src
	declare -gA  src_c
	declare -gA  src_v
	declare -gA  src_a
	declare -gA  src_s
	declare -gA  forgive
	declare -g   subs
	declare -g   subs_explicitly_requested
	declare -g   audio
	declare -g   audio_explicitly_requested
	declare -g   kilo
	declare -g   scale
	declare -g   crop
	declare -g   where_to_place_new_file="$PWD"
	declare -g   new_filename_user_prefix
	declare -g   max_size
	declare -g   vbitrate
	declare -g   scene_complexity
	declare -g   dryrun
	declare -g   do_not_report_ffmpeg_progress_to_console

	local  arg
	local  pid

	for arg in "${ARGS[@]}"; do
		if [[ "$arg" = @(-h|--help) ]]; then
			show_help

		elif [[ "$arg" = @(-v|--version) ]]; then
			show_version

		elif is_valid_timestamp "$arg"; then
			if [ ! -v time1  -a  ! -v time2 ]; then
				new_time_array  time1  "$arg"  || err 'Couldn’t set Time1'
			elif [ -v time1  -a  ! -v time2 ]; then
				new_time_array  time2  "$arg"  || err 'Couldn’t set Time2.'
			else
				err 'Cannot work with more than 2 timestamps.'
			fi

		elif [[ "$arg" =~ ^(no|)subs?((=|:)(.+)|)$ ]]; then
			#         external file ---^ ^---internal subtitle(!) track ID
			case "${BASH_REMATCH[1]}" in
				no)
					unset subs
					;;
				'')
					subs=t
					#  Remember, that subtitles were explicitly requested.
					#  This is needed to treat differently two cases:
					#  - “subs” are turned on by default. If a video would
					#    have no subs, Nadeshiko should be quiet and encode
					#    without subtitles.
					#  - “subs((=|:)(.+)|)” were set explicitly. In this case
					#    the lack of subtitles to render is an error.
					subs_explicitly_requested=t
					case "${BASH_REMATCH[3]}" in
						'=')
							src_s[external_file]="${BASH_REMATCH[4]}"
							[ -r "${src_s[external_file]}" ] || {
								redmsg "No such file:
								        ${src_s[external_file]}"
								err "External subtitles not found."
							}
							;;
						':')
							src_s[track_id]="${BASH_REMATCH[4]}"
							#  A more thorough check is done after gathering
							#  information about the source file.
							[[ "${src_s[track_id]}" =~ ^[0-9]+$ ]] || {
								redmsg "Subtitle track ID must be a number,
								        but it is set to “${src_s[track_id]}”."
								err "Wrong subtitle track ID."
							}
							;;
					esac
					;;
			esac

		elif [[ "$arg" =~ ^(no|)audio((=|:)(.+)|)$ ]]; then
			case "${BASH_REMATCH[1]}" in
				no) unset audio
					;;
				'')
					audio=t
					#  Remembering it for the same reason as with “subs”.
					audio_explicitly_requested=t
					case "${BASH_REMATCH[3]}" in
						'=')
							src_a[external_file]="${BASH_REMATCH[4]}"
							[ -r "${src_a[external_file]}" ] || {
								redmsg "No such file:
								        ${src_a[external_file]}"
								err "External audio file not found."
							}
							;;
						':')
							src_a[track_id]="${BASH_REMATCH[4]}"
							#  A more thorough check is done after gathering
							#  information about the source file.
							[[ "${src_a[track_id]}" =~ ^[0-9]+$ ]] || {
								redmsg "Audio track ID must be a number,
								        but it is set to “${src_a[track_id]}”."
								err "Wrong audio track ID."
							}
							;;
					esac
					;;
			esac

		elif [[ "$arg" =~ ^(si|kilo=1000|k=1000)$ ]]; then
			kilo=1000

		elif [[ "$arg" =~ ^($(IFS='|'; echo "${known_res_list[*]}"))p$ ]]; then
			scale="${BASH_REMATCH[1]}"

		elif [[ "$arg" =~ ^(tiny|small|normal|default|unlimited)$ ]]; then
			declare -gn max_size="max_size_$arg"

		elif [[ "$arg" =~ ^vb([0-9]+[kMG])$ ]]; then
			vbitrate="${BASH_REMATCH[1]}"

		elif [[ "$arg" =~ ^crop=([0-9]+):([0-9]+):([0-9]+):([0-9]+)$ ]]; then
			crop_w=${BASH_REMATCH[1]}
			crop_h=${BASH_REMATCH[2]}
			crop_x=${BASH_REMATCH[3]}
			crop_y=${BASH_REMATCH[4]}
			crop="crop=trunc($crop_w/2)*2:"
			crop+="trunc($crop_h/2)*2:"
			crop+="trunc($crop_x/2)*2:"
			crop+="trunc($crop_y/2)*2"

		elif [ "$arg" = do_not_report_ffmpeg_progress_to_console ]; then
			#
			#  This is a service option to shut the progressbar output. It is
			#    used by wrappers: Nadeshiko-mpv and Nadeshiko-do-postponed,
			#    whose logs get cluttered, because \r obviously does not work
			#    when the console output in the end gets redirected to a file.
			#  This option does not disable $ffmpeg_progress, so ffmpeg will
			#    still write the progress log, which makes possible for the
			#    wrappers to implement graphical progressbar (in the future).
			#
			do_not_report_ffmpeg_progress_to_console=t

		elif [ -f "$arg" ]; then
			[[ "$(mimetype -L -b "$arg")" =~ ^video/ ]]  \
				&& src[path]="$arg"

			#  There are two reasons to check for MPEG TS
			#  1. To force a keyframe at 0:00.000 during encoding and to
			#     put -ss and -to as *output* options. This is to avoid
			#     garbage-looking artefacts at the beginning.
			#  2. .ts (old MPEG transport stream) files cannot be recognised
			#     properly with mimetype (“mimetype -MLb” also doesn’t work,
			#     reports files as application/x-font-tex-tfm), so to recognise
			#     these input files as video, “file” is necessary to use.
			#     For that purpose, “file” is faster than mediainfo or ffprobe.
			#
			[[ "$(file -L -b  "$arg")" =~ MPEG\ transport\ stream ]] && {
				src_c[is_transport_stream]=t
				src[path]="$arg"
			}

			[ -v 'src[path]' ]  || {
				redmsg "Not a video file:
				        ${arg##*/}"
				err "Passed file is not a video."
			}

		elif [ -d "$arg" ]; then
			if [ -w "$arg" ]; then
				where_to_place_new_file="$arg"
			else
				redmsg "You must have writing permissions to place files in this directory:
				        $arg"
				err "Destination directory is not writeable."
			fi

		elif [[ "$arg" =~ ^fname_pfx=(.+)$ ]]; then
			#  User prefix for the name of the encoded file.
			#  - user might want to add a user prefix to the filename,
			#    e.g. to note who does what on the video.
			#  - test suite uses it to keep the encoded files in order.
			new_filename_user_prefix="${BASH_REMATCH[1]}"

		#  Internal use.
		#  Nadeshiko-mpv uses this with dryrun.
		elif [[ "$arg" =~ ^force_scene_complexity=(static|dynamic)$ ]]; then
			scene_complexity=${BASH_REMATCH[1]}
			scene_complexity_forced=t

		elif [ "$arg" = dryrun ]; then
			dryrun=t

		elif [[ "$arg" =~ ^forgive=(otf)$ ]]; then
			forgive+=( [otf]=yes )

		else
			err "“$arg”: parameter unrecognised."
		fi
	done

	return 0
}


return 0