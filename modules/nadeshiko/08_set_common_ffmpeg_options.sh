#  Should be sourced.

#  08_set_common_ffmpeg_options.sh
#  Nadeshiko module that translates the encoding parameters and flags into
#  ffmpeg command line options: input, output, video, audio, filtering
#  (to burn subtitles into video), stream mapping. Everything is prepared for
#  the codec-specific encoding module to grab the parameters and run ffmpeg.
#  © deterenkelt 2018–2020
#
#  For licence see nadeshiko.sh


put_time_before_the_ffmpeg_command() {
	declare -g ffmpeg
	declare -g time_applied

	[ -v time_stat -a ! -v time_applied ] && {
		#  Could be put in set_vars, but time is better to be applied after
		#  $vf_string is assembled, or we get conditional third time.
		ffmpeg="command time -f %e -o $LOGDIR/time_output -a $ffmpeg"
		time_applied=t
	}

	return 0
}


set_input_files() {
	declare -g  ffmpeg_input_files=( -i "${src[path]}" )

	#  External audio goes as a separate input file, subtitles go within the
	#  string passed as a parameter to -filter_complex
	if [ -v src_a[external_file]  ]; then
		ffmpeg_input_files+=( -i "${src_a[external_file]}" )
	fi
	return 0
}


set_colorspace_options() {
	declare -g  ffmpeg_colorspace_prepared
	declare -g  ffmpeg_color_primaries
	declare -g  ffmpeg_color_trc
	declare -g  ffmpeg_colorspace

	[ -v ffmpeg_colorspace  -a  ! -v ffmpeg_colorspace_prepared ] && {
		ffmpeg_color_primaries=(-color_primaries "$ffmpeg_color_primaries")
		ffmpeg_color_trc=(-color_trc "$ffmpeg_color_trc")
		ffmpeg_colorspace=(-colorspace "$ffmpeg_colorspace")
		ffmpeg_colorspace_prepared=t
	}
	return 0
}


 # Assembles -filter_complex string.
#  DO NOT put commas at the end of each filter, they can be tossed around
#  as they are.
#
assemble_vf_string() {
	declare -g  vf_string

	local filter_list
	local overlay_subs_w
	local overlay_subs_h
	local xcorr=0
	local ycorr=0
	local font_list
	local forced_style
	local key
	local tr_id
	local subtitle_filter

	 # In case the requested subtitles are built-in and in ASS/SSA format,
	#  they have to be extracted. This function extracts the ${src_s[track_id]}
	#  and sets  ${src_s[external_file]}  instead.  ${src_s[track_id]}  is then
	#  unset to avoid confusion in the later check.
	#
	extract_subs() {
		[ -v subtitles_are_already_extracted ] && return 0

		declare -g  src_s
		declare -g  subtitles_are_already_extracted

		info "Extracting subtitles…"
		src_s[external_file]="$TMPDIR/subs.ass"
		# NB: -map uses 0:s:<subtitle_track_id> syntax here.
		#   It’s the number among SUBTITLE tracks, not overall!
		# “?” in 0:s:0? is to ignore the lack of subtitle track.
		#   If the default setting is to add subs, it shouldn’t lead
		#   to an error, if the source simply doesn’t have subs:
		#   specifying “nosub” for them shouldn’t be a requirement.

		FFREPORT=file=$LOGDIR/ffmpeg-subs-extraction.log:level=32  \
		$ffmpeg -y -hide_banner  -v error  -nostdin  \
		        -i "${src[path]}"  \
		        -map 0:s:${src_s[track_id]}  \
		        "${src_s[external_file]}"  \
			|| err "Cannot extract subtitle stream ${src_s[track_id]}: ffmpeg error."
		sub-msg 'Ignore ffmpeg errors, if there are any.'
		unset src_s[track_id]
		#  Saving time on re-encodes.
		subtitles_are_already_extracted=t

		return 0
	}


	extract_fonts() {
		[ -v fonts_are_already_extracted ] && return 0

		declare -g  font_list
		declare -g  fonts_are_already_extracted

		local font

		info "Extracting fonts…"
		milinc
		[ -d "$TMPDIR/fonts" ] || mkdir "$TMPDIR/fonts"
		if (( src_c[attachments_count] > 0 ));  then
			pushd "$TMPDIR/fonts" >/dev/null
			if ! FFREPORT=file=$LOGDIR/ffmpeg-fonts-extraction.log:level=32  \
			     $ffmpeg  -hide_banner  -v error  -nostdin  \
			              -dump_attachment:t ""  -i "${src[path]}"
			then
				#  FFmpeg may complain about that “At least one output file must
				#  be specified” but extracts all attachments. And God forbid you
				#  to try “-f null -” for this will make FFmpeg ACTUALLY START
				#  TRANSCODING the video.
				mildec  # ffmpeg’s message will not obey our indentation, so…
				sub-msg "Ignore the ffmpeg message about output, if the numbers below match."
				milinc  # back to one level deep
			fi
			info "Extracted $(ls -1A | wc -l)/${src_c[attachments_count]} attachments."
			popd >/dev/null
			font_list=$(
				find "$TMPDIR/fonts" \( -iname "*.otf" -o -iname "*.ttf" \)
			)
			for font in ${font_list[@]}; do
				if	   [[ "$font" =~ \.[Oo][Tt][Ff]$ ]]   \
					&& [ -v ffmpeg_missing[fontconfig] ]  \
					&& [ ! -v forgive[otf]  ]
				then
					redmsg 'Video uses .otf fonts, but FFmpeg was built without fontconfig
					        and will not be able to render subtitles with their native fonts.'
					redmsg 'Please install the missing fonconfig support for FFmpeg.
					        Alternatively (if you’re in a hurry and you don’t care,
					        what mess may happen in the subtitle rendering), you may re-run
					        nadeshiko with “forgive=otf” flag to bypass this error.'
					err 'FFmpeg is not able to render OTF fonts.
					     See the log for details.'
				fi
			done
		else
			info 'Video has no attachments.'
		fi

		if	[ "$subtitle_filter" = 'ass' ]  \
			&& [ -v src_s[external_file] ]  \
			&& grep -qEi '^\s*\[Fonts\]\s*$' "${src_s[external_file]}"
		then
			. "$LIBDIR/dump_attachments_from_ass_subs.sh"
			ass_dump_fonts "${src_s[external_file]}" "$TMPDIR/fonts"
		fi

		mildec
		#  Saving time on re-encodes.
		fonts_are_already_extracted=t
		return 0
	}


	[ -v scale ] || [ -v subs ] || [ -v crop ] && {
		[ -v subs ] && {
			case "${src_s[codec]}" in

				dvd_subtitle|hdmv_pgs_subtitle)
					#  Internal VobSub or PGS (dvd and bluray) require
					#  mapping and overlay filter.
					filter_list="${filter_list:+$filter_list,}"
					#  Subtitles may need to be centered, if their resolution
					#  doesn’t match with the video’s.
					overlay_subs_w=$( get_ffmpeg_attribute "${src[path]}"  \
					                                       "s:${src_s[track_id]}"  \
					                                       width  )
					overlay_subs_h=$( get_ffmpeg_attribute "${src[path]}"  \
					                                       "s:${src_s[track_id]}"  \
					                                       height  )

					 # HDMV_PGS_SUBTITLE hack
					#  In some bluray (rips) subtitle stream width and height
					#    are set to “N/A”.
					#  Nadeshiko assumes, that if the subtitle stream resolu-
					#    tion wouldn’t match the resolution of the video stream,
					#    then these metadata must be present. (Otherwise how
					#    would it play?)
					#
					[ "$overlay_subs_w" = 'N/A' ]  \
						&& overlay_subs_w=${src_v[width]}
					[ "$overlay_subs_h" = 'N/A' ]  \
						&& overlay_subs_h=${src_v[height]}


					 # Overlay subtitle correction is implemented for DVD subs
					#  though it may be useful for HDMV PGS too.
					#
					(( overlay_subs_w != src_v[width] )) && {
						#  Need to center by X
						(( overlay_subs_w > src_v[width] ))  \
							&& xcorr="-(overlay_w-main_w)/2"  \
							|| xcorr="(main_w-overlay_w)/2"
					}
					(( overlay_subs_h != src_v[height] )) && {
						#  Need to center by Y
						(( overlay_subs_h > src_v[height] ))  \
							&& ycorr="-(overlay_h-main_h)/2"  \
							|| ycorr="(main_h-overlay_h)/2"
					}

					#  Breaks syntax highlight, if put inside as is.
					local tr_id=${src_s[track_id]}
					filter_list+="[0:v][0:s:$tr_id]overlay=$xcorr:$ycorr"
					;;

				ass|ssa|subrip|srt|webvtt|vtt)
					filter_list="${filter_list:+$filter_list,}"
					filter_list+="setpts=PTS+$(( ${start[total_ms]}/1000 )).${start[ms]}/TB,"
					#  “ass” filter has an option “shaping” for better font
					#  rendering, that’s not available in the “subtitles”
					#  filter. But on the other hand, “ass” doesn’t recognise
					#  option “force_style”, so we can’t use it for converted
					#  SubRip/VTT subs.
					if [[ "${src_s[codec]}" =~ ^(subrip|srt|webvtt|vtt)$ ]]; then
						subs_need_style_from_rc=t
						subtitle_filter='subtitles'
					else
						subtitle_filter='ass'
						#  “ass” filter, being true to its name, cannot be specified
						#  subtitle track id within the video. Yes, it copies the
						#  behaviour of the “subtitles” filter, but here it does
						#  not – be so kind to disembowel the file, that may take
						#  20 gigs on the disk to take out subtitles and put it
						#  on a silver plate to ffmpeg as a separate file.
						#  REEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE—
						[ -v src_s[track_id]  ]  && extract_subs
					fi
					filter_list+="$subtitle_filter="

					#  Composing the next part of the filter string depends
					#  on whether the subtitles are in an external file or they
					#  are builtin.
					if [ -v src_s[external_file]  ]; then
						src_s[symlink_to_ext_subs]="$TMPDIR/extsubs.${src_s[external_file]##*\.}"
						[ -v overshot_times ]  \
							|| ln -s "${src_s[external_file]}" "${src_s[symlink_to_ext_subs]}"
						filter_list+="filename=${src_s[symlink_to_ext_subs]}"

					elif [ -v src_s[track_id]  ]; then
						#  “ass” filter, being true to its name, requires the
						#  subtitle stream to be extracted from the file, before
						#  it can be encoded. (See the comments above.)
						[ "$subtitle_filter" = 'ass' ]  \
							&& err 'Internal subtitle track should have been extracted!'
						#  To use built-in subtitles without taking them out, the
						#  subtitles filter needs to be specified *the filename*
						#  with subtitle track index. As escaping ${src[path]} will
						#  probably lead to errors anyway, it’s simpler to create
						#  a symlink in TMPDIR and tell ffmpeg to use the file
						#  via that symlink.
						src[symlink_to_my_path]="$TMPDIR/THE_VIDEO.${src[path]##*\.}"
						ln -s "${src[path]}" "${src[symlink_to_my_path]}"
						filter_list+="${src[symlink_to_my_path]}:si=${src_s[track_id]}"
					fi

					extract_fonts

					[ -v extra_fonts_dir ] && {
						noglob_off
						ln -s "$extra_fonts_dir"/*  -b -t $TMPDIR/fonts/  &>/dev/null  \
							|| true
						noglob_on
					}
					[ "${font_list:-}" ]  \
						&& filter_list+=":fontsdir=$TMPDIR/fonts"

					[ -v subs_need_style_from_rc ] && {
						(( ${#ffmpeg_subtitle_fallback_style[*]} > 0 )) && {
							for key in ${!ffmpeg_subtitle_fallback_style[@]}; do
								forced_style="${forced_style:+$forced_style,}"
								forced_style+="$key="
								forced_style+="${ffmpeg_subtitle_fallback_style[$key]}"
							done
							filter_list+=":force_style='$forced_style'"
						}
					}

					#  For OpenType positioning and substitutions.
					[ "$subtitle_filter" = 'ass' ]  \
						&& filter_list+=':shaping=complex'

					#  There may be three variants:
					#  - subtitles=$TMPDIR/subs.ass:fontsdir=…,
					#  - subtitles=$TMPDIR/subs.ass:force_style=…,
					#  - or just subtitles=$TMPDIR/subs.ass,
					filter_list+=','
					filter_list+='setpts=PTS-STARTPTS'
					;;

			esac
		}
		[ -v crop ] && {
			filter_list="${filter_list:+$filter_list,}"
			filter_list+="$crop"
		}
		[ -v scale ] && {
			filter_list="${filter_list:+$filter_list,}"
			filter_list+="scale=-2:$scale"
		}
	}
	#  Assemble $vf_string only if $filter_list is not empty.
	[ "${filter_list:-}" ] && vf_string=(-filter_complex "$filter_list")
	return 0
}


map_streams() {
	declare -g map_string=()
	local map_audio=()

	[ -v audio ] && {
		if [ -v src_a[external_file]  ]; then
			map_audio=( -map 1:a:0 )
		else
			map_audio=( -map 0:a:${src_a[track_id]} )
		fi
	}
	map_string=( -map 0:V  "${map_audio[@]}" )
	return 0
}


set_audio_options() {
	#  Codec options from the audio profile in the RC file(s).
	#  Declared as global to be available to the encoding module,
	#  in case it would need those.
	declare -g  acodec_options
	#  The set of audio options, that is substituted into ffmpeg command.
	declare -g  audio_opts

	if [ -v audio ]; then
		declare -n acodec_options=${ffmpeg_acodec}_profiles[$acodec_profile]
		audio_opts=( -c:a $ffmpeg_acodec -ac 2 $acodec_options )
	else
		audio_opts=( -an )
	fi

	return 0
}


set_file_name_and_video_title() {
	declare -g  new_file_name
	declare -g  video_title

	local scale_type_tag
	local filename
	local filename_with_user_prefix
	local filename_without_user_prefix
	local timestamps
	local tags

	filename="${src[path]%.*}"
	filename=${filename##*/}
	filename_with_user_prefix="${new_filename_user_prefix:-} $filename"
	filename_with_user_prefix=${filename_with_user_prefix## }
	filename_without_user_prefix="$filename"
	filename_without_user_prefix=${filename_without_user_prefix## }
	[ -v new_filename_user_prefix ]  \
		&& local -n filename='filename_with_user_prefix' \
		|| local -n filename='filename_without_user_prefix'

	timestamps=" ${start[ts]}–${stop[ts]}"

	[ -v scale ] && {
		#  FS – forced scale, AS – automatic scale
		#  (including the scale= from .rc.sh).
		[ -v forced_scale ]  \
			&& scale_type_tag="FS"   \
			|| scale_type_tag="AS"
		tags=" [${scale}p][$scale_type_tag]"
	}

	new_file_name="$filename$timestamps${tags:-}.$container"
	new_file_name="$where_to_place_new_file/$new_file_name"

	video_title="${src_c[title]:-}"
	[ "${src_c[title]:-}" ]  \
		|| video_title="$filename_without_user_prefix"
	video_title+=".$timestamps${tags:-}"
	[ -v create_windows_friendly_filenames ]  \
		&& new_file_name="$(remove_windows_unfriendly_chars "$new_file_name")"

	return 0
}


set_common_ffmpeg_options() {

	put_time_before_the_ffmpeg_command

	set_input_files

	set_colorspace_options

	assemble_vf_string

	map_streams

	set_audio_options

	set_file_name_and_video_title

	return 0
}


return 0