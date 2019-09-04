#  Should be sourced.

#  nadeshiko_stage02_arguments_processing.sh
#  Nadeshiko module that contains functions for parsing, verifying,
#  and processing arguments. It also has a function that would
#  display the initial set of parameters.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh


 # Assigns start time, stop time, source video file
#  and other stuff from command line parameters.
#  $@ – see show_help()
#
parse_args() {
	declare -gA src  src_c  src_v  src_a  src_s  forgive
	declare -g  subs  subs_explicitly_requested  \
	            audio  audio_explicitly_requested  \
	            kilo  scale  crop  where_to_place_new_file="$PWD"  \
	            new_filename_user_prefix  max_size  vbitrate  abitrate  \
	            scene_complexity  dryrun  \
	            do_not_report_ffmpeg_progress_to_console
	local args=("$@")  arg  pid

	for arg in "${args[@]}"; do
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

		elif [[ "$arg" =~ ^(vb|ab)([0-9]+[kMG])$ ]]; then
			[ "${BASH_REMATCH[1]}" = vb ] && vbitrate="${BASH_REMATCH[2]}"
			[ "${BASH_REMATCH[1]}" = ab ] && abitrate="${BASH_REMATCH[2]}"

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

			[[ "$arg" =~ \.(TS|ts)$ ]]  && {
				#  .ts (old MPEG transport stream) cannot be recognised proper-
				#  ly and file has to be used. (“mimetype -MLb” also doesn’t
				#  work, reports file as application/x-font-tex-tfm.)
				[[ "$(file -L -b  "$arg")" =~ MPEG\ transport\ stream ]]  \
					&& src[path]="$arg"
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

	[  -v src[path]  ] || err "Source video is not specified."
	return 0
}


 # Check, that all needed utils are in place and ffmpeg supports
#  user’s encoders.
#
check_basic_util_support() {
	declare -g REQUIRED_UTILS  REQUIRED_UTILS_HINTS
	#  Encoding modules may need to know versions of ffmpeg or its libraries.
	declare -g  ffmpeg_version_output  ffmpeg_ver  \
	            libavutil_ver  libavcodec_ver  libavformat_ver
	local  ffmpeg="$ffmpeg -hide_banner"
	REQUIRED_UTILS+=(
		#  For encoding. 3.4.2+ recommended.
		ffmpeg

		#  For retrieving data from the source video
		#  and verifying resulting video.
		mediainfo

		#  For the parts not retrievable with mediainfo
		#  and as a fallback option.
		ffprobe

		#  To parse mediainfo output.
		xmlstarlet

		#  To determine the mime types of video and subtitle files
		#  correctly, “file” command is not sufficient.
		mimetype

		#  However, only “file” reports correctly the MIME type
		#  for MPEG transport stream files of the old format.
		file

		#  For the floating point calculations, that are necessary
		#  e.g. in determining scene_complexity.
		bc
	)
	REQUIRED_UTILS_HINTS+=(
		[ffprobe]='ffprobe comes along with FFmpeg.
		https://www.ffmpeg.org/'

		[mimetype]='mimetype is a part of File-MimeInfo.
		https://metacpan.org/pod/File::MimeInfo'
	)
	check_required_utils

	#  Checking ffmpeg version
	ffmpeg_version_output=$($ffmpeg -version)
	# (( $(get_user_verbosity log user) > 0 ))  \
	# 	&& echo "$ffmpeg_version_output" > "$LOGDIR/ffmpeg_version"
	ffmpeg_ver=$(
		sed -rn '1 s/ffmpeg version (\S+) .*/\1/p' <<<"$ffmpeg_version_output"
	)
	libavutil_ver=$(
		sed -rn '/^libavutil/ { s/^[^\/]+\/(.+)$/\1/; s/\s//g; p }'  \
			<<<"$ffmpeg_version_output"
	)
	libavcodec_ver=$(
		sed -rn '/^libavcodec/ { s/^[^\/]+\/(.+)$/\1/; s/\s//g; p }'  \
			<<<"$ffmpeg_version_output"
	)
	libavformat_ver=$(
		sed -rn '/^libavformat/ { s/^[^\/]+\/(.+)$/\1/; s/\s//g; p }'  \
			<<<"$ffmpeg_version_output"
	)
	is_version_valid "$libavutil_ver" || {
		redmsg "Incorrect version for libavutil: “$libavutil_ver”."
		err "Cannot determine libavutil version!"
	}
	is_version_valid "$libavcodec_ver" || {
		redmsg "Incorrect version for libavcodec: “$libavcodec_ver”."
		err "Cannot determine libavcodec version!"
	}
	is_version_valid "$libavformat_ver" || {
		redmsg "Incorrect version for libavformat: “$libavformat_ver”."
		err "Cannot determine libavformat version!"
	}
	info "System ffmpeg: $ffmpeg_ver
	      libavutil   $libavutil_ver
	      libavcodec  $libavcodec_ver
	      libavformat $libavformat_ver"
	if	   compare_versions "$libavutil_ver" '<' "$libavutil_minver"  \
		|| compare_versions "$libavcodec_ver" '<' "$libavcodec_minver"  \
		|| compare_versions "$libavformat_ver" '<' "$libavformat_minver"
	then
		redmsg 'The FFmpeg version you are running is too old!'
		cat <<-EOF | column -t  -o '    '  -N ' ','Needed','In your FFmpeg' | sed -r "s/.*/$__mi&/g"
		libavutil      $libavutil_minver+      $libavutil_ver
		libavcodec     $libavcodec_minver+     $libavcodec_ver
		libavformat    $libavformat_minver+    $libavformat_ver
		EOF
		err 'FFmpeg is too old.'
	fi
	return 0
}


check_video_encoder_support() {
	local encoder_info
	#  It is confirmed, that when a codec is not supported, ffmpeg returns
	#      “Codec '<name>' is not recognized by FFmpeg”.
	#  (FFmpeg N-94168-g0f39ef4db2, 5 July 2019)
	encoder_info=$(
		$ffmpeg -hide_banner -h encoder="$ffmpeg_vcodec" | head -n1
	)
	[[ "${encoder_info:-}" =~ ^Encoder\ $ffmpeg_vcodec\  ]] || {
		redmsg "“$ffmpeg_vcodec” video codec is missing."
		return 1
	}
	return 0
}


check_audio_encoder_support() {
	local encoder_info
	#  It is confirmed, that when a codec is not supported, ffmpeg returns
	#      “Codec '<name>' is not recognized by FFmpeg”.
	#  (FFmpeg N-94168-g0f39ef4db2, 5 July 2019)
	encoder_info=$(
		$ffmpeg -hide_banner -h encoder="$ffmpeg_acodec" | head -n1
	)
	[[ "$encoder_info" =~ ^Encoder\ $ffmpeg_acodec\  ]] || {
		redmsg "“$ffmpeg_acodec” audio codec is missing."
		return 1
	}
	return 0
}


check_subtitle_filter_support() {
	local encoder_info  subtitle_filter  helpmsg  font_rendering_problems  \
	      quit_with_error
	#
	#  ASS filter:
	#    - OpenType font features can be enabled only with the “ass”
	#      filter, not available with “subtitles” filter;
	#    - depends on libass;
	#    - “Same as the subtitles filter, except that it doesn’t require
	#      libavcodec and libavformat to work.” ― FFmpeg filters documentation.
	#
	#  Subtitles fitler:
	#    - depends on libass;
	#
	#  At this point src_s[codec] is guaranteed to have a value
	#    from $known_sub_codecs.
	#
	case "${src_s[codec]}" in
		ass|ssa)
			subtitle_filter='ass'
			helpmsg="Make sure that FFmpeg is compiled with “--enable-libass”."
			;;

		subrip|srt|webvtt|vtt)
			subtitle_filter='subtitles'
			helpmsg="Make sure that FFmpeg is compiled with “--enable-libass”."
			;;

		dvd_subtitle|hdmv_pgs_subtitle)
			subtitle_filter='overlay'
			#  No $helpmsg, because dependencies for the “overlay” filter
			#  are not known.
			;;
	esac
	helpmsg=${helpmsg:+$helpmsg$'\n'}
	helpmsg+="Try encoding without subtitles? (Add “nosub” to cmdline options.)"
	#
	#  It is confirmed, that when “ass” subtitle codec IS NOT supported,
	#  `ffmpeg -h encoder=ass` still returns
	#      “Encoder ass [ASS (Advanced SubStation Alpha) subtitle]:
	#       General capabilities: none”
	#  while for `ffmpeg -h filter=ass` it returns
	#      “Unknown filter 'ass'.”
	#  (FFmpeg N-94168-g0f39ef4db2, 5 July 2019)
	#
	encoder_info=$(
		$ffmpeg -hide_banner -h filter="$subtitle_filter" | head -n1
	)
	[[ "$encoder_info" =~ ^Filter\ $subtitle_filter ]] || {
		redmsg "“$subtitle_filter” subtitle filter is missing."
		[ -v helpmsg ] && msg "$helpmsg"
		quit_with_error=t
	}

	 # If the subtitle filter to be used is “ass”, then also check,
	#  that the OpenType features are supported.
	#
	[[ "$subtitle_filter" =~ ^(ass|subtitles)$ ]] && {
		if [    "${ffmpeg_version_output}"  \
		      = "${ffmpeg_version_output/enable-fontconfig/}"  ]
		then
			warn "FFmpeg was built without fontconfig!"
			ffmpeg_missing+=( [fontconfig]=yes )
			font_rendering_problems=t
		fi

		if [    "${ffmpeg_version_output}"  \
		      = "${ffmpeg_version_output/enable-libfreetype/}"  ]
		then
			warn "FFmpeg was built without freetype!"
			ffmpeg_missing+=( [freetype]=yes )
			font_rendering_problems=t
		fi

		[ -v font_rendering_problems ]  \
			&& warn "Without freetype and fontconfig libraries FFmpeg won’t be able to use
			         OpenType fonts (.otf), features like kerning and ligatures will be
			         missing, and the text may be not rendered at all!"
	}

	[ -v quit_with_error ]  \
		&& return 1  \
		|| return 0
}


check_encoder_support() {
	local  missing_components  arg
	info 'Verifying, that FFmpeg supports the required V/A/S codecs…'
	milinc
	for arg in "$@"; do
		case "$arg" in
			video)
				check_video_encoder_support || missing_components=t
				;;
			audio)
				check_audio_encoder_support || missing_components=t
				;;
			subs)
				check_subtitle_filter_support || missing_components=t
				;;
		esac
	done
	[ -v missing_components ]  \
		&& err "FFmpeg doesn’t support required encoders or filters."
	mildec
	return 0
}


check_misc_util_support() {
	declare -g REQUIRED_UTILS  REQUIRED_UTILS_HINTS
	local arg

	for arg in "$@"; do
		case "$arg" in
			time_stat)
				REQUIRED_UTILS+=(
					#  To output how many seconds the encoding took.
					#  Only pass1 and pass2, no fonts/subtitles extraction.
					time
				)
				;;
			check_for_updates)
				. "$LIBDIR/bahelite/bahelite_github.sh"
				;;
			ffmpeg_progressbar)
				REQUIRED_UTILS+=(
					#  To temporarily switch off the cursor while drawing
					#  a progressbar for ffmpeg
					tput
				)
				;;
		esac
	done
	REQUIRED_UTILS_HINTS+=(
		[time]='time is found in the package of the same name.
		https://www.gnu.org/directory/time.html'

		[tput]='tput belongs to the ncurses package.
		https://www.gnu.org/software/ncurses/'
	)
	check_required_utils
	return 0
}


check_muxing_set() {
	declare -g ffmpeg_muxer container
	local i  combination  combination_passes  muxer_info  \
	      ffmpeg="$ffmpeg -hide_banner"

	[ "$container" = auto ] && {
		for combination in "${muxing_sets[@]}"; do
			[[ "$combination" =~ ^([^[:space:]]+)[[:space:]]+$ffmpeg_acodec$ ]]  \
				&& container="${BASH_REMATCH[1]}"  \
				&& break
		done
	}
	for combination in "${muxing_sets[@]}"; do
		[[ "$combination" =~ ^$container[[:space:]]+$ffmpeg_acodec$ ]]  \
			&& combination_passes=t  \
			&& break
	done
	#  Muxer is the FFmpeg name of the chosen container.
	#  It may or may not correspond to the common name (file extension).
	[[ "$container" =~ ^[A-Za-Z0-9_-]+$ ]]  \
		|| err "Invalid container: “$container”."

	ffmpeg_muxer=${ffmpeg_muxers[$container]}
	muxer_info=$($ffmpeg -h muxer="$ffmpeg_muxer" | head -n1)
	[[ "$muxer_info" =~ ^Muxer\ $ffmpeg_muxer\  ]]  \
		|| err "FFmpeg doesn’t support muxing into “$container” container."
	[ -v combination_passes ] || {
		redmsg "“$container”, “$ffmpeg_vcodec” and “$ffmpeg_acodec” cannot be used together.
		        Possible combinations are:
		        $(for ((i=0; i<${#muxing_sets[@]}; i++)); do
		              vcodec=$ffmpeg_vcodec
		              acodec=${muxing_sets[i]##* }
		              container=${muxing_sets[i]%% *}
		              echo "  $((i+1)). $vcodec + $acodec → $container"
		          done)"
		err 'Incompatible set of container format and A/V codecs.'
	}
	return 0
}


check_mutually_exclusive_options() {
	[ -v abitrate  -a  ! -v audio ]  \
		&& err "“noaudio” cannot be used with forced audio bitrate."
	[ -v crop  -a  -v scale ]  \
		&& err "“crop” and “scale” cannot be used at the same time."
	return 0
}


check_times() {
	#  Getting video duration to compare with the requested.
	#  If we couldn’t retrieve it, it’s not critical.
	new_time_array  mediainfo_source_duration  \
	                "${src_v[duration_total_s_ms]}"  \
		|| true

	[ ! -v time1  -a  ! -v time2 ] && {
		#  If neither Time1 nor Time2 is set, use the full video duration.
		new_time_array  time1  "00:00:00.000"  \
			|| err 'Couldn’t set Time1 to 00:00:00.000'
		new_time_array  time2  "${mediainfo_source_duration[ts]}"  \
			|| err "Couldn’t set Time2 to ${mediainfo_source_duration[ts]}"
	}
	(( ${time2[total_ms]} > ${time1[total_ms]} ))  \
		&& declare -gn start='time1'  stop='time2'  \
		|| declare -gn start='time2'  stop='time1'
	(( ${time1[total_ms]} == ${time2[total_ms]} ))  \
		&& err 'Time1 and Time2 are the same.'

	new_time_array   duration  \
	                "$(total_ms_to_total_s_ms "$((   ${stop[total_ms]}
	                                               - ${start[total_ms]} ))" )"
	if [ -v mediainfo_source_duration ]; then
		if [[ "${mediainfo_source_duration[total_s]}" =~ ^[0-9]+$ ]]; then
			#  Trying to prevent negative space_for_video_track.
			(( ${start[total_s]} > ${mediainfo_source_duration[total_s]} ))  \
				&& err "Start time ${start[ts]#00:} is behind the end."
			(( ${stop[total_s]} > ${mediainfo_source_duration[total_s]} ))  \
				&& err "Stop time ${stop[ts]#00:} is behind the end."
		else
			unset mediainfo_source_duration
		fi
	else
		#  We still can try to work, there is a check
		#  for negative space_for_video_track ahead.
		unset mediainfo_source_duration
	fi
	return 0
}


check_subtitles() {
	declare -g subs_need_extraction  subs_need_conversion  prepped_ext_subs
	local  codec_name  known_sub_codecs_list  ext_subtitle_type

	known_sub_codecs_list=$(IFS='|'; echo "${known_sub_codecs[*]}")

	if [ -v src_s[external_file]  ]; then
		[[ "${src_s[codec]}" =~ ^($known_sub_codecs_list)$ ]] || {
			#  External subs can only be requested,
			#    so it’s always an error, when they can’t be rendered.
			#  This error may be triggered, if mpv or a wrapper like
			#    smplayer load every text file in the directory, thinking
			#    it’s subtitles. The option is called “fuzzy matching”.
			err "Cannot use external subtitles – “${src_s[mimetype]}” type is not supported."
		}

	else
		#  FFmpeg counts streams of specific type (video, audio, subs) from 0.
		[  -v src_s[track_id]  ] && {
			local track_id=$(( ${src_s[track_id]} +1 ))
			(( track_id > ${src_c[subtitle_streams_count]} )) && {
				if (( ${src_c[subtitle_streams_count]} == 0 )); then
					err "Cannot use $(nth "$track_id") subtitle track – the video has none."
				else
					err "Cannot use $(nth "$track_id") subtitle track – the video has only ${src_c[subtitle_streams_count]}."
				fi
			}
		}

		#  Subtitle stream was requested (probably by default), but the source
		#  file has no built-in subtitles. This happens, it is not an error.
		if (( ${src_c[subtitle_streams_count]:-0} == 0 )); then
			info "No subtitle track to add. Disabling hardsub."
			unset subs
			return 0
		else
			: ${src_s[track_id]:=0}
		fi
		#  Now the stage04_encoding.sh module can refer to streams
		#  as s:${src_s[track_id]} with confidence, no need in …:-0?}

		#  Unlike with a video that simply has no subtitle stream,
		#  having one that we cannot encode is always an error.
		[[ "${src_s[codec]}" =~ ^($known_sub_codecs_list)$ ]]  \
			|| err "Cannot use built-in subtitles – “${src_s[codec]}” type is not supported. Try “nosubs”?"
		#  Sic! ---------------------------------------------^^^^^

	fi

	return 0
}


check_audio() {
	[ ! -v src_a[external_file]  ]  && {

		[ -v src_a[track_id] ] && {
			#  FFmpeg counts streams of specific type (video, audio, subs) from 0.
			local track_id=$(( ${src_a[track_id]} +1 ))
			(( track_id > ${src_c[audio_streams_count]} )) && {
				if (( ${src_c[audio_streams_count]} == 0 )); then
					err "Cannot use $(nth "$track_id") audio track – the video has none. Try “noaudio”?"
				else
					err "Cannot use $(nth "$track_id") audio track – the video has only ${src_c[audio_streams_count]}.  Try “noaudio”?"
				fi
			}
		}

		#  If audio stream was requested (e.g. by default), but the source
		#  file has no audio track. This happens, it is not an error.
		if (( ${src_c[audio_streams_count]} == 0 )); then
			info "No audio track to add. Disabling sound."
			unset audio
			return 0
		else
			: ${src_a[track_id]:=0}
		fi
		#  Now the stage04_encoding.sh module can refer to streams
		#  as a:${src_a[track_id]} with confidence, no need in …:-0?}

	}
	return 0
}


 # Determines how fast the scenes in the video change.
#  For example, a 30 seconds video may contain 2–3 static scenes with somebody
#    having a dinner under a tree, or it may be an opening, which is filled
#    with dynamic scenes that change every 2–3 seconds on top of that.
#  These two videos would have different requirements for the bitrate to pre-
#    serve quality, hence for the dynamic one we want to lock available bit-
#    rates to the desired value (and if it won’t fit, then IMMEDIATELY go one
#    resolution lower, unless the difference between the desried bitrate and
#    what fits is marginal.
#  See also:
#  https://github.com/deterenkelt/Nadeshiko/wiki/Tests.-Video-complexity
#
#  TAKES
#    $1 – video
#    $2 – start time (whatever format ffmpeg reads)
#    $3 – duration (between start and stop time, in total_s_ms, e.g. 125.500)
#    $4 – duration in total seconds with rounded up milliseconds.
#
#  SETS
#    scene_complexity to either “static” or “dynamic”.
#
determine_scene_complexity() {
	declare -g  scene_complexity  scene_complexity_assumed
	local video="$1" start_time="$2" stop_time="$3" \
	      duration_total_s="$4" total_scenes is_dynamic

	total_scenes=$(
		FFREPORT=file=$LOGDIR/ffmpeg-scene-complexity.log:level=32 \
		$ffmpeg  -hide_banner  -v error  -nostdin  \
		         -ss "$start_time"  -to "$stop_time"  -i "${src[path]}" \
		         -vf "select='gte(scene,0.3)',metadata=print:file=-" \
		         -an -sn -f null -
	) || err "Couldn’t determine scene complexity: ffmpeg error."

	total_scenes=$(
		grep -cE '^lavfi\.scene_score=0\.[0-9]{6}$' <<<"$total_scenes" || true
		# When ffmpeg finds no scene changes – and there may be none, if the
		# clip is simply too short to have them – grep will print the count
		# as “0” to stdout, but will quit with return code 1 as no matches
		# were found. || : is to prevent quitting here.
	)

	[[ "$total_scenes" =~ ^[0-9]+$ ]] && {
		((total_scenes++, 1))  # add the initial scene
		sps_ratio=$(
			echo "scale=2; $duration_total_s / $total_scenes" | bc
		) || true
		#                      dynamic < $video_sps_threshold < static
		is_dynamic=$(
			echo "$sps_ratio < $video_sps_threshold" | bc
		) || true
		[[ "$is_dynamic" =~ ^[01]$ ]] && {
			case "$is_dynamic" in
				0) # 0 = negative in bc
					scene_complexity='static'
					;;
				1) # 1 = positive in bc
					scene_complexity='dynamic'
					;;
			esac
		}
	}

	#  If the type is undeterminable, allow the use
	#  of bitrate–resolution ranges.
	[ -v scene_complexity ] || {
		warn 'Cannot determine video complexity, assuming static.'
		scene_complexity='static'
		scene_complexity_assumed=t
	}


	return 0
}


 # Verifies the input data further, prepares the necessary files
#    and sets (or unsets) variables.
#  Uses only warnings and errors, info for the user is printed
#    later by display_settings().
#
set_vars() {
	declare -g orig_vcodec_format  orig_acodec_format  \
	           # source_video_container=$(mimetype -L -b -d "${src[path]}")
	local  i  output_framerate

	check_muxing_set

	#  “||…” because [ -v ${container}_space_reserved_frames_to_esp ]
	#  is impossible.
	declare -gn container_space_reserved_frames_to_esp=${container}_space_reserved_frames_to_esp  || {
		warn "No predicted overhead table is specified for the $container container.
		      If the video exceeds maximum file size, re-encode will be inevitable."
		declare -g container_space_reserved_frames_to_esp=( [0]=0 )
	}

	[ -v max_size ] || declare -g max_size=$max_size_default
	check_mutually_exclusive_options
	#  $1 = Type of information to gather.
	#  $2 = name for the new global variable that will store the data.
	gather_info 'before-encode' 'src'
	check_times
	#  Frame count is used as primary indicator of the expected muxing overhead.
	output_framerate=${custom_output_framerate:-${src_v[frame_rate]}}
	frame_count=$(echo "scale=3;  fc =    ${duration[total_s_ms]}  \
	                                    * $output_framerate;
	                    scale=0;  fc/1"  | bc                    )

	 # There are three sources for subtitles:
	#  - default subtitle track (if any present at all), ffmpeg’s -map 0:s:0?;
	#  - an external file, specified in the “subs” parameter
	#    in the command line as subs=/path/to/external/file;
	#  - an internal subtitle track, but not the default one: it’s specified
	#    through the command line as well, as subs:5 for example.
	#
	[ -v subs ] && check_subtitles
	[ -v audio ] && check_audio

	 # Original resolution is a prerequisite for the intelligent mode.
	#    Dumb mode with some hardcoded default bitrates bears
	#    little usefulness, so it was decided to flex it out.
	#    Intelligent and forced modes (that overrides things in the former)
	#    are the two modes now.
	#  Getting native video resolution is of utmost importance
	#    to not do accidental upscale. It is also needed for knowing,
	#    with which resolution to start scaling down, if needed.
	#
	[  -v src_v[resolution]  ] || err "Couldn’t determine source video resolution."


	#  Since the values in our bitrate–resolution profiles are given
	#  for 16:9 aspect ratio, 4:3 video and special ones like 1920×820
	#  would require less bitrate, as there’s less pixels.

	if     [ -v src_v[aspect_ratio]  ]  \
		&& [ -v src_v[is_16to9]  ]  \
		&& [ "${src_v[is_16to9]}" = 'no' ]
	then
		needs_bitrate_correction_by_origres=t
	fi

	[  -v src_v[resolution]  ] && {
		#  Videos with nonstandard resolutions must be associated
		#    with a higher profile.
		#  [ -v doesn’t work here, somehow O_o
		declare -p bitres_profile_${src_v[height]}p  &>/dev/null  || {
			for ((i=${#known_res_list[@]}-1; i>0; i--)); do
				(( src_v[height] > known_res_list[i] ))  \
					&& continue  \
					|| break
			done
			(( i == -1 )) && ((i++, 1))  # sic!
			closest_res=${known_res_list[i]}
			needs_bitrate_correction_by_origres=t
		}
	}


	[ -v crop  -a  ! -v crop_uses_profile_vbitrate ]  \
		&& needs_bitrate_correction_by_cropres=t

	[ -v scale ] && (( scale == src_v[height] )) && {
		warn "Disabling scale to ${scale}p – it is the native resolution."
		unset scale
	}
	[ -v scale ] && (( scale > src_v[height] )) && {
		warn "Disabling scale to ${scale}p – would be an upscale."
		unset scale
	}


	shopt -s nocasematch
	for codec_format in ${vcodec_name_as_formats[@]}; do
		[[ "$codec_format" = "${src_v[format]}" ]]  \
			&& orig_vcodec_same_as_enc=t  \
			&& break
	done

	for codec_format in ${acodec_name_as_formats[@]}; do
		[[ "$codec_format" = "${src_a[format]}" ]]  \
			&& orig_acodec_same_as_enc=t  \
			&& break
	done
	shopt -u nocasematch

	closest_lowres_index=0
	for ((i=0; i<${#known_res_list[@]}; i++ )); do
		# If a profile resolution is greater than or equal
		#   to the source video height, such resolution isn’t
		#   actually lower, and we don’t need upscales.
		# If we intend to scale down the source and the desired
		#   resolution if higher than the table resolution,
		#   again, it should be skipped.
		(
			[  -v src_v[height]  ] && (( known_res_list[i] >= src_v[height] ))
		)||(
			[ -v scale ] && (( known_res_list[i] > scale ))
		) \
		&& ((closest_lowres_index++, 1))
	done

	 # If any of these variables are set by this time,
	#  they force (fixate) corresponding settings.
	[ -v vbitrate ] && forced_vbitrate=t
	[ -v abitrate ] && forced_abitrate=t
	#  scale is special, it can be set in RC file.
	[ -v scale  -a  ! -v rc_default_scale ] && forced_scale=t


	if [ -v scene_complexity ]; then
		info "Scene complexity is requested as ${__bri}${__w}$scene_complexity${__s}."
		milinc
	else
		info 'Determining scene complexity.
		      It takes 2–20 seconds depending on video.'
		milinc
		determine_scene_complexity "${src[path]}"         \
		                           "${start[ts]}"         \
		                           "${stop[ts]}"          \
		                           "${duration[total_s]}"
	fi
	[ "$scene_complexity" = dynamic ] && {
		info "Locking video bitrates on desired values."
		vbitrate_locked_on_desired=t
	}
	mildec

	return 0
}


 # Prints the initial settings to the user.
#  This output combines the data from the RC file, the command line,
#  and the source video. No decision how to fit the clip in the constraints
#  has been made yet.
#
display_settings() {
	local sub_hl  audio_hl  crop_string  sub_hl  audio_hl  \
	      src_var  src_varval  key
	# The colours for all the output should be:
	# - default colour for default/computed/retrieved data;
	# - bright white colour indicates command line overrides;
	# - bright yellow colour shows the changes, that the code applied itself.
	#   This includes lowering bitrates for 4:3 videos, going downscale,
	#   when the size doesn’t allow for encode at the native resolution etc.
	info 'Requested settings:' && milinc
	info "$ffmpeg_vcodec + $ffmpeg_acodec → $container"
	# Highlight only overrides of the defaults.
	# The defaults are defined in $rc_file.
	[ -v rc_default_subs -a -v subs ] \
		&& sub_hl="${__g}" \
		|| sub_hl="${__bri}"
	[ -v subs ] \
		&& info "Subtitles are ${sub_hl}ON${__s}." \
		|| info "Subtitles are ${sub_hl}OFF${__s}."
	[ -v rc_default_audio -a -v audio ] \
		&& audio_hl="${__g}" \
		|| audio_hl="${__bri}"
	[ -v audio ] \
		&& info "Audio is ${audio_hl}ON${__s}." \
		|| info "Audio is ${audio_hl}OFF${__s}."
	[ -v scale ] && {
		[ "${rc_default_scale:-}" != "${scale:-}" ] && scale_hl=${__bri}
		info "Scaling to ${scale_hl:-}${scale}p${__s}."
	}
	[ -v crop ] && {
		crop_string="${__bri}$crop_w×$crop_h${__s}, X:$crop_x, Y:$crop_y"
		info "Cropping to: $crop_string."
	}
	[ "$max_size" = "$max_size_default" ] \
		&& info "Size to fit into: $max_size (kilo=$kilo)." \
		|| info "Size to fit into: ${__bri}$max_size${__s} (kilo=$kilo)."
	info "Slice duration: ${duration[ts_short_no_ms]} (exactly ${duration[total_s_ms]})."

	mildec
	info 'Source video properties:'
	milinc

	for src_var in  src_c  src_v  src_a  src_s; do
		[ "$src_var" = src_a ] && [ ! -v audio ] && continue
		[ "$src_var" = src_s ] && [ ! -v subs  ] && continue
		local -n src_varval=$src_var
		case $src_var in
			src_c)
				msg 'Container'
				;;
			src_v)
				msg 'Video'
				;;
			src_a)
				msg 'Audio'
				;;
			src_s)
				msg 'Subtitles'
				;;
		esac
		milinc
		for key in ${!src_varval[*]}; do
			msg "$key: ${src_varval[$key]}"
		done
		mildec
	done
	mildec

	info 'Clip properties:'
	milinc
	if [ -v scene_complexity_assumed ]; then
		warn "Scene complexity: assumed to be $scene_complexity."
	else
		if [ -v forced_scene_complexity ]; then
			msg "Scene complexity: ${__bri}$scene_complexity${__s}."
		else
			msg "Seconds per scene: ${sps_ratio:-scene complexity is forced}."
			msg "Scene complexity: $scene_complexity."
		fi
	fi
	msg "Frame count: $frame_count"
	mildec

	local -n vcodec_pix_fmt=${ffmpeg_vcodec//-/_}_pix_fmt
	[ "$vcodec_pix_fmt" != "yuv420p" ] \
		&& info "Encoding to pixel format “${__bri}$vcodec_pix_fmt${__s}”."
	[ -v ffmpeg_colorspace ] \
		&& info "Converting to colourspace “${__bri}$ffmpeg_colorspace${__s}”."
	[    -v needs_bitrate_correction_by_origres \
	  -o -v needs_bitrate_correction_by_cropres ] && {
	  	infon 'Bitrate corrections to be applied: '
		[ -v needs_bitrate_correction_by_origres ] \
			&& echo -en "by ${__y}${__bri}orig_res${__s} "
		[ -v needs_bitrate_correction_by_cropres ] \
			&& echo -en "by ${__y}${__bri}crop_res${__s} "
		echo
	}

	#  Separating the prinout of the initial properties
	#  from the calculations that will follow.
	echo
	return 0
}


return 0
