#  Should be sourced.

#  gather_file_info.sh
#  A set of functions to get information with ffmpeg and mediainfo.
#  © deterenkelt 2018
#
#  For licence see nadeshiko.sh



 # FFmpeg helps to retrieve several attributes, that mediainfo doesn’t report.
#  - subtitle codec name ;
#  - subtitle resolution for DVD and BD subtitle resolution, without which
#    it isn’t possible to center them right in stage04.
#
#  $1 – video
#  $2 – stream type (v, a, s)
#  $3 – key name
#
get_ffmpeg_attribute() {
	local  video="$1"  stype="$2"  key="$3"
	#  If the stream number isn’t set, assume the first one.
	case "${stype:0:1}" in
		v) stype_full='video';;
		a) stype_full='audio';;
		s) stype_full='subtitle';;
	esac
	if [[ "$stype" =~ ^[vas](\:[0-9]+|)$ ]]; then
		[ "${BASH_REMATCH[1]}" ] || stype+=':0'
	else
		err "Invalid stype: “$stype”."
	fi
	set -o pipefail
	#  For BDMV ffprobe will return duplicated strings, because
	#  there are secondary stream entries in the [PROGRAM] section.
	#  We leave only the [STREAM] part by reading the last line only.
	ffprobe -hide_banner -v error -select_streams $stype  \
	        -show_entries stream=$key  \
	        -of default=noprint_wrappers=1:nokey=1  \
	        "$video"  \
		| sed -n '$p'  \
		|| err "Cannot retrieve “$stype_full” property “$key”: ffmpeg error."
	set +o pipefail
	return 0
}



                   #  New way of retrieving info  #

 # Notes about mediainfo and ffprobe backends
#
#  tl;dr: both are shit, and just one cannot be used (though mediainfo
#  does the job most of the time).
#
#
 # Notes about mediainfo backend
#
#  - XML and OLDXML output formats highly differ, a property with the same
#    name may return value in different formats.
#  - Do not use OLDXML output – it returns properties’ values in several
#    formats, but leaves them in the same tags, dammit. Since neither xmlstar-
#    let, nor xmllint nor any other tool supports fancy XPath functions like
#    matches(), it is easier to use plaintext output and parse it with sed,
#    than trying to make sense of this bullshit.
#  - XML output provides values, that are surprisingly sensible in comparison
#    to the default and OLDXML outputs. These values must only be checked,
#    they do not require conversion to some other format, that would be conve-
#    nient for Nadeshiko. XML output has a nuance with namespaces, see below.
#
#
 # Notes about ffprobe backend
#  - It allows to select the format (representation) of the data with command
#    line parameters.
#  - On the other hand, the stream bitrate must be retrieved in some cases
#    from the stream data field, and in other – from a subsection called “tags”.
#    Unpredictable behaviour makes this tool inconvenient.
#  - JSON format should be used to request data
#
#        $ ffprobe -hide_banner  \
#                  -v error  \
#                  -print_format json=string_validation=replace:string_validation_replacement=ffprobe_could_not_retrieve_the_data  \
#                  -show_streams -select_streams v:0  \
#                                -select_streams a:1  \
#                  -show_entries format=bit_rate,filename,start_time:stream=duration,width,height,display_aspect_ratio,r_frame_rate,bit_rate \
#                  -sexagesimal
#                   ^ print times in HH:MM:SS.sssssssss format
#
#  - Disregard the “flat” format, it is simple, but will create too much
#    variables, than we need. However, why not try it out.
#    -print_format=flat=sep_char=_:hierarchical=1
#                                               ^ 1 or 0
#
#  - XML format may be considered to lower the count of dependencies
#    (ditch jq and use xmlstarlet for both the mediainfo and ffprobe output)
#    However, jq is necessary for Nadeshiko-mpv to read data via mpv IPC
#    protocol, so it is a dependency anyway.
#
#  - ffprobe options to consider:
#    “-unit” – shows the unit of the displayed values.
#    “-prefix” – orders to use SI prefixes for the displayed values. Unless
#                the “-byte_binary_prefix” option is used all the prefixes
#                are decimal.
#    “-byte_binary_prefix” – forces the use of binary prefixes for byte values.
#
#  - It is probably not possible to use
#        -select_streams v:0
#    and
#        -select_streams a:0
#    together, because only one stream will be selected then. Instead, the
#    -show_entries options should be used, however, its format is heavy to
#    understand:
#        1. https://ffmpeg.org/ffprobe.html#Main-options
#        2. Ctrl+F show_entries
#    It is unclear, whether -show_entries can be forced to output only
#    specified streams (the used video and the used audio) to reduce the
#    volume of the output. The JSON output would probably have to be
#    additionally parsed by jq to filter out the unnecessary streams or
#    the stream specifiers will have to be passed to jq so it would select
#    only the necessary data.


 # Grabs information about a video file from mediainfo and other means.
#  $1 – mode (defined preset of which values are retrieved)
#  $2 – variable name to which stuff the data. The variable must already
#       exist, be an associative array and have [path] element set.
#
#  Something to remember:
#  This function only *gathers* data. Because of that, it doesn’t set track_id
#    property for subtitles and audio track to the number of the selected track.
#    However, it still gathers information about the track, that is selected
#    by default (you don’t have to set  track_id  beforehand, so that the
#    data about the default track could be gathered).
#  Nadeshiko sets  track_id  for the default track when all the further checks
#    are done. This makes the presence of  track_id  element an indicator of
#    whether the default track is present at the next stages of the program.
#    The expression (( ${src_c[subtitle_streams_count]} == 0 )) does the same,
#    [  -v src_s[track_id]  ]  is simply shorter.
#  That  track_id  presence may be checked at the second stage of this program
#    removes the necessity to use the 0 and the question mark in stream speci-
#    fiers for the ffmpeg commands later (as long as there is a check
#    on [ -v subs ] before that):
#        ffmpeg … -map 0:s:${src_s[track_id]:-0?}
#                                           ^^^^  isn’t needed any more
#  This function gathers information about the external subtitles and audio
#    tracks, if  [external_file]  element is set before calling it. When an
#    external file is specified, built-in tracks are ignored.
#  If the selected track is one among built-in ones, this function will
#    set and use  [track_specifier]  element to identify it. If the [track_id]
#    element would be set before calling this function, it will affect the
#    value of [track_specifier].
#
gather_info() {
	local mode="$1" varname="$2"
	declare -gA "${varname}"    # File per se properties
	declare -gA "${varname}_c"  # Container track properties
	declare -gA "${varname}_v"  # Video ——»——
	declare -gA "${varname}_a"  # Audio ——»——
	declare -gA "${varname}_s"  # Subtitles ——»——
	local -n source="${varname}"
	local -n source_c="${varname}_c"
	local -n source_v="${varname}_v"
	local -n source_a="${varname}_a"
	local -n source_s="${varname}_s"
	local -a to_gather_props
	local -a to_gather_container_props
	local -a to_gather_video_props
	local -a to_gather_audio_props
	local -a to_gather_subtitle_props


	 # Using the new mediainfo format “XML” seems to be the lesser evil, for
	#  it reports the data in the needed format, but it requires expressions
	#  to use namespace. (Can be parsed out with sed, but eh.)
	#
	local xml=(xmlstarlet  sel -N x="https://mediaarea.net/mediainfo" -t -v)


	 # Modes are named sets of options. When a particular set of options
	#  needs to be set, it is requested by name and this function sets them.
	#
	#  “init” – video, basic container opts, if/audio if/subs
	#  “post-check” – init + fsize + full container check
	#
	case "$mode" in
		before-encode)
			to_gather_props=(
				# 'path'  #  Must be set beforehand.
				'mediainfo'
			)
			to_gather_container_props=(
				'format'
				'duration_total_s_ms'
				'audio_streams_count'
				'subtitle_streams_count'
				'title'
				'attachments'
				'attachments_count'
			)
			to_gather_video_props=(
				'format'
				'duration_total_s_ms'
				'bitrate'
				'width'
				'height'
				'resolution'
				'resolution_total_px'
				'aspect_ratio'
				'is_16to9'
				'frame_rate'
			)
			[ -v audio ] && {
				to_gather_audio_props=(
					# 'external_file'  #  May or may not be set beforehand.
					'format'
					'format_profile'
					'is_lossless'
					'bitrate'
					'channels'
				)
			}
			[ -v subs ] && {
				to_gather_subtitle_props=(
					# 'external_file'  #  May or may not be set beforehand.
					'codec'
				)
			}
			;;
		container-ratios)
			to_gather_props=(
				# 'path'  #  Must be set beforehand.
				'mediainfo'
				'fsize_B'
				'fsize_kB'
				'fsize_MiB'
			)
			to_gather_container_props=(
				'format'
				'duration_total_s_ms'
				'muxing_overhead_B'
				'ratio_to_fsize_pct'
				'ratio_to_1sec_of_playback'
				'bitrate_by_extraction'
			)
			to_gather_video_props=(
				'format'
				'duration_total_s_ms'
				'stream_size_by_extraction_B'
				'bitrate_by_extraction'
				'width'
				'height'
				'resolution'
				'resolution_total_px'
				'aspect_ratio'
				'is_16to9'
				'frame_count'
				'frame-heaviness'
				'pix_fmt'
			)
			to_gather_audio_props=(
				'format'
				'stream_size_by_extraction_B'
				'bitrate_by_extraction'
			)
			;;
	esac


	for prop in "${to_gather_props[@]}"; do
		gather_info_${prop}
	done
	for container_prop in "${to_gather_container_props[@]}"; do
		gather_info_container_${container_prop}
	done
	for video_prop in "${to_gather_video_props[@]}"; do
		gather_info_video_${video_prop}
	done
	for audio_prop in "${to_gather_audio_props[@]}"; do
		gather_info_audio_${audio_prop}
	done
	for subtitle_prop in "${to_gather_subtitle_props[@]}"; do
		gather_info_subtitle_${subtitle_prop}
	done

	return 0
}



                      #  Info about file per se  #

gather_info_mediainfo() {
	source[mediainfo]=$(mediainfo --Full --Output=XML "${source[path]}")
}

gather_info_fsize_B() {
	source[fsize_B]=$(stat --format %s "${source[path]}")
	[[ "${source[fsize_B]}" =~ ^[0-9]+$ ]] || unset source[fsize_B]
	return 0
}

gather_info_fsize_kB() {
	[ -v source[fsize_B]  ] || return 0
	source[fsize_kB]=$(( source[fsize_B]/1024 ))
	return 0
}

gather_info_fsize_MiB() {
	[ -v source[fsize_B]  ] || return 0
	source[fsize_MiB]=$(( source[fsize_B]/1024/1024 ))
	return 0
}



                          #  Container info  #

gather_info_container_title() {
	source_c[title]=$(
		${xml[@]} '//x:track[@type="General"]/x:Title'  \
			<<<"${source[mediainfo]}"  \
			2>/dev/null
	) || unset source_v[title]
	return 0
}

gather_info_container_format() {
	source_c[format]=$(
		${xml[@]} '//x:track[@type="General"]/x:Format'  \
			<<<"${source[mediainfo]}"  \
			2>/dev/null
	) || unset source_v[format]
	return 0
}

gather_info_container_format_version() {
	source_c[format_version]=$(
		${xml[@]} '//x:track[@type="General"]/x:Format_version'  \
			<<<"${source[mediainfo]}"  \
			2>/dev/null
	) || unset source_c[format_version]
	return 0
}

gather_info_container_subtitle_streams_count() {
	source_c[subtitle_streams_count]=$(
		${xml[@]} '//x:track[@type="General"]/x:TextCount'  \
			<<<"${source[mediainfo]}"  \
			2>/dev/null
	) || unset source_c[subtitle_streams_count]
	return 0
}

gather_info_container_audio_streams_count() {
	source_c[audio_streams_count]=$(
		${xml[@]} '//x:track[@type="General"]/x:AudioCount'  \
			<<<"${source[mediainfo]}"  \
			2>/dev/null
	) || unset source_c[audio_streams_count]
	return 0
}


 # Some containers will have duration specified in the container metadata,
#  so it will work as a backup for the length of the video stream.
#
gather_info_container_duration_total_s_ms() {
	source_c[duration_total_s_ms]=$(
		${xml[@]} '//x:track[@type="General"]/x:Duration'  \
			<<<"${source[mediainfo]}"
	) || true
	#  Check.
	#  The format in this field differs, so assuming, that it may be
	#  “N”, “N.NNN” or “N.NNNNNNNNN”. We need to guarantee, that it conforms
	#  to either first or the second format, and strip extra ms precision:
	#  6400.360xxxxxx → 6400.360
	[[ "${source_c[duration_total_s_ms]}" =~ ^([0-9]+)((\.[0-9]{1,3})[0-9]*|)$ ]]  \
		&& source_c[duration_total_s_ms]="${BASH_REMATCH[1]}${BASH_REMATCH[3]}"  \
		|| unset source_c[duration_total_s_ms]
	return 0
}


gather_info_container_bitrate_by_extraction() {
	gather_info_video_bitrate_by_extraction
	gather_info_audio_bitrate_by_extraction
	source_c[bitrate_by_extraction]=$((
	                                      ${source_v[bitrate_by_extraction]:-0}
	                                    + ${source_a[bitrate_by_extraction]:-0}
	))
	return 0
}


gather_info_container_muxing_overhead_B() {
	gather_info_video_stream_size_by_extraction_B
	gather_info_audio_stream_size_by_extraction_B
	[ -v source_v[stream_size_by_extraction_B] ] || return 0
	#  May be not set, if the file has no audio
	#[ -v source_a[stream_size_by_extraction_B] ] || return 0
	source_c[muxing_overhead_B]=$((      source[fsize_B]
	                                 -   source_v[stream_size_by_extraction_B]
	                                 - ${source_a[stream_size_by_extraction_B]:-0}
	))
	[[ "${source_c[bitrate_by_extraction]}" =~ ^[0-9]$ ]]  \
		|| unset source_c[bitrate_by_extraction]
	return 0
}


gather_info_container_ratio_to_fsize_pct() {
	gather_info_container_muxing_overhead_B
	[ -v source_c[muxing_overhead_B]  ] || return 0
	source_c[ratio_to_fsize_pct]=$(
		echo "scale=4;    ${source_c[muxing_overhead_B]}  \
		                * 100  \
		                / ${source[fsize_B]}"  | bc
	)
	[[ "${source_c[ratio_to_fsize_pct]}" =~ ^[0-9]*(\.[0-9]+|)$ ]]  \
		|| unset source_c[ratio_to_fsize_pct]
	return 0
}


gather_info_container_ratio_to_1sec_of_playback() {
	local one_second_of_playback
	gather_info_container_muxing_overhead_B
	[ -v source_c[muxing_overhead_B]  ] || return 0
	gather_info_video_bitrate_by_extraction
	[ -v source_v[bitrate_by_extraction]  ] || return 0

	#  Audio may be unset – there are webms without audio
	gather_info_audio_bitrate_by_extraction
	# [ -v source_a[bitrate_by_extraction]  ] || return 0

	one_second_of_playback=$((    ( ${source_v[bitrate_by_extraction]}    / 8)
	                            + ( ${source_a[bitrate_by_extraction]:-0} / 8)
	                                                                          ))
	source_c[ratio_to_1sec_of_playback]=$(
		echo "scale=4;   ${source_c[muxing_overhead_B]}   \
		               / $one_second_of_playback"  | bc
	)
	[[ "${source_c[ratio_to_1sec_of_playback]}" =~ ^[0-9]*(\.[0-9]+|)$ ]]  \
		|| unset source_c[ratio_to_1sec_of_playback]
	return 0
}


gather_info_container_attachments() {
	[ -v source_c[attachments]  ]  && return 0
	source_c[attachments]=$(
		${xml[@]} '//x:track[@type="General"]/x:extra/x:Attachments'  \
			<<<"${source[mediainfo]}"
	) || true
	return 0
}


gather_info_container_attachments_count() {
	gather_info_container_attachments
	local att="${source_c[attachments]}"  att_nodividers
	if [ "$att"  ]; then
		#
		#  The string holds attachments separated with “ / ”: a space, then
		#  a slash and one more space.
		#  Example:  "font1.otf / font2.ttf / FONT3.TTF"
		#  So the number of slashes is the attachment count minus one.
		#
		att_nodividers="${att// \/ /}"
		source_c[attachments_count]=$((
			(${#att} - ${#att_nodividers}) / 3  +1
		))
	else
		#  Empty string guarantees that mediainfo reported no attachments.
		source_c[attachments_count]=0
	fi
	return 0
}



                        #  Video track info  #

gather_info_video_format() {
	source_v[format]=$(
		${xml[@]} '//x:track[@type="General"]/x:Format'  \
			<<<"${source[mediainfo]}"  \
			2>/dev/null
	) || unset source_v[format]
	return 0
}


 # May be important in the determining original quality for some codecs,
#  e.g. VC-1.
#
# gather_info_video_format_profile() {
# 	source_v[format_profile]=$(
# 		${xml[@]} '//x:track[@type="General"]/x:Format_Profile'  \
# 			<<<"${source[mediainfo]}"  \
#			2>/dev/null
# 	)
# }
#
# gather_info_video_format_level() {
# 	source_v[format_level]=$(
# 		${xml[@]} '//x:track[@type="General"]/x:Format_Level'  \
# 			<<<"${source[mediainfo]}"  \
#			2>/dev/null
# 	)
# }


 # May be needed in the future.
#
# gather_info_video_codec_id() {
# 	source_v[codec_id]=$(
# 		${xml[@]} '//x:track[@type="General"]/x:CodecID'  \
# 			<<<"${source[mediainfo]}"  \
#			2>/dev/null
# 	)
# }
#
# #  Property may or may not be present
# gather_info_video_codec_profile() {
# 	#  Verify the property name.
# 	source_v[codec_profile]=$(
# 		${xml[@]} '//x:track[@type="General"]/x:Codec_profile'  \
# 			<<<"${source[mediainfo]}"  \
#			2>/dev/null
# 	)
# }


 # If we will be comparing source pix_fmt with $ffmpeg_pix_fmt specified in RC,
#  this would come useful. Comparing itself is needed, if some day there will
#  be implemented cutting by streamcopying, i.e. without transcoding. Then we
#  will need to compare colourspace, chroma and bitness, which is most easy
#  to do by ffmpeg’s pix_fmt parameter (mediainfo returns them separate). And
#  anyway, we’re bound to compare with how ffmpeg defines them, because Nade-
#  shiko encodes with ffmpeg and the option that defines outgoing colourspace/
#  chroma/bitness is $ffmpeg_pix_fmt.
#
gather_info_video_pix_fmt() {
	source_v[pix_fmt]=$(get_ffmpeg_attribute "${source[path]}"  v  pix_fmt)
}


gather_info_video_duration_total_s_ms() {
	source_v[duration_total_s_ms]=$(
		${xml[@]} '//x:track[@type="Video"]/x:Duration'  \
			<<<"${source[mediainfo]}"
	) || true
	#  Check.
	#  The format in this field differs, so assuming, that it may be
	#  “N”, “N.NNN” or “N.NNNNNNNNN”. We need to guarantee, that it conforms
	#  to either first or the second format, and strip extra ms precision:
	#  6400.360xxxxxx → 6400.360
	#
	if [[ "${source_v[duration_total_s_ms]}" =~ ^([0-9]+)((\.[0-9]{1,3})[0-9]*|)$ ]]; then
		source_v[duration_total_s_ms]="${BASH_REMATCH[1]}${BASH_REMATCH[3]}"
	elif [ -v source_c[duration_total_s_ms]  ]; then
		source_v[duration_total_s_ms]=${source_c[duration_total_s_ms]}
	else
		unset source_v[duration_total_s_ms]
	fi
	return 0
}


gather_info_video_bitrate() {
	source_v[bitrate]=$(
		${xml[@]} '//x:track[@type="Video"]/x:BitRate'  \
			<<<"${source[mediainfo]}"
	) || true
	[[ "${source_v[bitrate]}" =~ ^[0-9]+$ ]] || {
		source_v[bitrate]=$(
			${xml[@]} '//x:track[@type="Video"]/x:NominalBitRate'  \
				<<<"${source[mediainfo]}"
		) || true
	}
	#  Check
	[[ "${source_v[bitrate]}" =~ ^[0-9]+$ ]]  || unset source_v[bitrate]
	return 0
}


gather_info_video_width() {
	[ -v source_v[width]  ] && return 0
	source_v[width]=$(
		${xml[@]} '//x:track[@type="Video"]/x:Width'  \
			<<<"${source[mediainfo]}"
	) || true
	#  Check
	[[ "${source_v[width]}" =~ ^[0-9]+$ ]] || unset source_v[width]
	return 0
}


gather_info_video_height() {
	[ -v source_v[height]  ] && return 0
	source_v[height]=$(
		${xml[@]} '//x:track[@type="Video"]/x:Height'  \
			<<<"${source[mediainfo]}"
	) || true
	#  Check
	[[ "${source_v[height]}" =~ ^[0-9]+$ ]] || unset source_v[height]
	return 0
}


 # Resolution is most commonly used to check, if the width and height
#  are set (that is, to check the existence of one variable instead of two).
#  Its actual value is probably never used.
#
gather_info_video_resolution() {
	[ -v source_v[resolution]  ] && return 0
	gather_info_video_height
	[ -v source_v[height]  ] || return 0
	gather_info_video_width
	[ -v source_v[width]  ] || return 0
	[[ -v source_v[width]  &&  -v source_v[height] ]]  \
		&& source_v[resolution]="${source_v[width]}×${source_v[height]}"
	return 0
}


gather_info_video_resolution_total_px() {
	[ -v source_v[resolution_total_px]  ] && return 0
	gather_info_video_height
	[ -v source_v[height]  ] || return 0
	gather_info_video_width
	[ -v source_v[width]  ] || return 0
	[[ -v source_v[width]  &&  -v source_v[height] ]]  \
		&& source_v[resolution_total_px]=$(( source_v[width] * source_v[height] ))
	return 0
}


gather_info_video_aspect_ratio() {
	source_v[aspect_ratio]=$(
		${xml[@]} '//x:track[@type="Video"]/x:DisplayAspectRatio'  \
			<<<"${source[mediainfo]}"
	) || true
	#  Check
	[[ "${source_v[aspect_ratio]}" =~ ^[0-9]+(\.[0-9]+|)$ ]]  \
		|| unset source_v[aspect_ratio]
	return 0
}


gather_info_video_is_16to9() {
	gather_info_video_aspect_ratio || return 0
	if [  -v source_v[aspect_ratio]  ]; then

		 # A mistake in the video resolution, e.g. 848×480 instead of the right
		#  848×360 (cinemascope 2.35:1), may lead to a false ratio 1.76, that
		#  looks close to 1.77, making a wrong assumption, that the video
		#  should have a 16:9 aspect ratio (that it doesn’t really have).
		#  Double check the video resolution of your test samples. 16:9 ratio
		#  remains 1.77 for all resolutions between 360p and 2160p.
		#
		[[ "${source_v[aspect_ratio]}" =~ ^1\.77 ]]  \
			&& source_v[is_16to9]='yes'  \
			|| source_v[is_16to9]='no'
	else
		source_v[is_16to9]='undefined'
	fi
	return 0
}


gather_info_video_frame_count() {
	source_v[frame_count]=$(
		${xml[@]} '//x:track[@type="Video"]/x:FrameCount'  \
			<<<"${source[mediainfo]}"
	) || true
	[[ "${source_v[frame_count]}" =~ ^[0-9]+$ ]]  \
		|| unset source_v[frame_count]
	return 0
}


gather_info_video_frame-heaviness() {
	gather_info_video_frame_count
	[ -v source_v[frame_count]  ] || return 0
	gather_info_video_resolution_total_px
	[ -v source_v[resolution_total_px]  ] || return 0

	source_v[frame-heaviness]=$((    source_v[frame_count]
	                               * source_v[resolution_total_px]  ))
	# source_v[frame-heaviness]=$((    source_v[frame_count]
	#                                * (
	#                                      source_v[resolution_total_px]
	#                                    * source_v[muxovhead_coeff]
	#                                  )
	#                                * (
	#                                      source_v[bitrate]
	#                                    * source_v[muxovhead_coeff]
	#                                  )
	#                            ))

	return 0
}


gather_info_video_stream_size_by_extraction_B() {
	[ -v source_v[stream_size_by_extraction_B]  ] && return 0
	local raw_stream="$TMPDIR/vid.raw"
	rm -f "$raw_stream"
	#  Assuming, that webms that we test all have video track GOING FIRST,
	#  i.e. video stream id is 0 (Mkvextract operates on the whole bunch
	#  of streams without subdivision by kind), audio track has id 1.
	mkvextract "${source[path]}" tracks --fullraw "0:$raw_stream"  &>/dev/null
	source_v[stream_size_by_extraction_B]=$( stat -c %s "$raw_stream" )
	[[ "${source_v[stream_size_by_extraction_B]}" =~ ^[0-9]+$ ]]  \
		|| unset source_v[stream_size_by_extraction_B]
	return 0
}


gather_info_video_bitrate_by_extraction() {
	[ -v source_v[bitrate_by_extraction]  ] && return 0
	gather_info_video_stream_size_by_extraction_B
	[ -v source_v[stream_size_by_extraction_B]  ] || return 0
	[ -v source_c[duration_total_s_ms]  ] || return 0
	source_v[bitrate_by_extraction]=$(
		echo "scale=2;  br =     ${source_v[stream_size_by_extraction_B]}  \
		                       * 8  \
		                       / ${source_c[duration_total_s_ms]};  \
		      scale=0;  br/1" | bc
	)
	[[ "${source_v[bitrate_by_extraction]}" =~ ^[0-9]+$ ]]  \
		|| unset source_v[bitrate_by_extraction]
	return 0
}


gather_info_video_frame_rate() {
	source_v[frame_rate]=$(
		${xml[@]} '//x:track[@type="Video"]/x:FrameRate'  \
			<<<"${source[mediainfo]}"
	)
	[[ "${source_v[frame_rate]}" =~ ^([0-9]+)(\.[0-9]+|)$ ]]  \
		|| unset source_v[frame_rate]
	return 0
}


 # May be needed in the future.
#
# gather_info_video_frame_rate_mode() {
# 	source_v[frame_rate_mode]=$(
# 		${xml[@]} '//x:track[@type="Video"]/x:FrameRate_Mode'  \
# 			<<<"${source[mediainfo]}"
# 	)
# }

# gather_info_video_colour_space () {
# 	source_v[colour_space]=$(
# 		${xml[@]} '//x:track[@type="Video"]/x:ColorSpace'  \
# 			<<<"${source[mediainfo]}"
# 	)
# }

# gather_info_video_chroma_subsampling () {
# 	source_v[chroma_subsampling]=$(
# 		${xml[@]} '//x:track[@type="Video"]/x:ChromaSubsampling'  \
# 			<<<"${source[mediainfo]}"
# 	)
# }

# gather_info_video_bit_depth () {
# 	source_v[bit_depth]=$(
# 		${xml[@]} '//x:track[@type="Video"]/x:BitDepth'  \
# 			<<<"${source[mediainfo]}"
# 	)
# }

# gather_info_video_colour_primaries () {
# 	source_v[colour_primaries]=$(
# 		${xml[@]} '//x:track[@type="Video"]/x:colour_primaries'  \
# 			<<<"${source[mediainfo]}"
# 	)
# }

# gather_info_video_transfer_characteristics () {
# 	source_v[transfer_characteristics]=$(
# 		${xml[@]} '//x:track[@type="Video"]/x:transfer_characteristics'  \
# 			<<<"${source[mediainfo]}"
# 	)
# }

# gather_info_video_matrix_coefficients () {
# 	source_v[matrix_coefficients]=$(
# 		${xml[@]} '//x:track[@type="Video"]/x:matrix_coefficients'  \
# 			<<<"${source[mediainfo]}"
# 	)
# }



               #  Audio track / audio external file info  #

 # Prepares mediainfo data, if the audio track is in an external file.
#
__gather_audio_info_check_for_external_file() {
	#  This is for the future.
	#  Nadeshiko doesn’t work with external audio files yet.
	[ -v source_a[external_file] ] && {
		[ -v source_a[external_file_mediainfo] ] || {
			source_a[external_file_mediainfo]=$(
				mediainfo --Full  \
				          --Output=XML  \
				          "${source_a[external_file]}"
			)
		}
	}
	return 0
}


 # Setting track specifier.
#  This is a track ID that mediainfo marks each stream of the same type with,
#    like the FFmpeg a:0, a:1 etc.
#  If there are two or more audio tracks in the container, then
#    the second and above will have a “typeorder” attribute, by which
#    they can be selected.
#  Track specifier isn’t needed, when audio track is in an external file,
#    since an external file will always have only one track and there
#    cannot be any “typeorder” attribute.
#
__gather_audio_info_set_track_specifier() {
	#  Already set? Nothing to do.
	[  -v source_a[track_specifier]  ] && return 0
	#  Finally, if we use a built-in audio track, we need to know, if there
	#    is only one – then “typeorder” attribute won’t be there, – or there are
	#    2+, in which case “typeorder” will be present.
	#  Typeorder values in the mediainfo output start from 1, i.e. if there
	#    would be two audio tracks, they would have numbers “1” and “2”.
	#    Contrary to that, ffmpeg – and the source_a[track_id] follow 0-based
	#    order. Both mediainfo and ffmpeg refer to the number of the track
	#    among its kind, audio in this case.
	(( source_c[audio_streams_count] > 1 ))  \
		&& source_a[track_specifier]="[@typeorder=\"$(( ${source_a[track_id]:-0} +1 ))\"]"
	return 0
}


gather_info_audio_format() {
	if [  -v source_a[external_file]  ]; then
		__gather_audio_info_check_for_external_file
		source_a[format]=$(
			${xml[@]} '//x:track[@type="Audio"]/x:Format'  \
				<<<"${source_a[external_file_mediainfo]}"  \
				2>/dev/null
		) || unset source_a[format]
	elif (( source_c[audio_streams_count] > 0 )); then
		__gather_audio_info_set_track_specifier
		source_a[format]=$(
			${xml[@]} "//x:track[@type=\"Audio\"]${source_a[track_specifier]:-}/x:Format"  \
				<<<"${source[mediainfo]}"  \
				2>/dev/null
		) || unset source_a[format]
	else
		:  #  No audio tracks – nothing to set.
	fi
	return 0
}


gather_info_audio_format_profile() {
	if [  -v source_a[external_file]  ]; then
		__gather_audio_info_check_for_external_file
		source_a[format_profile]=$(
			${xml[@]} '//x:track[@type="Audio"]/x:Format_Profile'  \
				<<<"${source_a[external_file_mediainfo]}"  \
				2>/dev/null
		) || unset source_a[format_profile]
	elif (( source_c[audio_streams_count] > 0 )); then
		__gather_audio_info_set_track_specifier
		source_a[format_profile]=$(
			${xml[@]} "//x:track[@type=\"Audio\"]${source_a[track_specifier]:-}/x:Format_Profile"  \
				<<<"${source[mediainfo]}"  \
				2>/dev/null
		) || unset source_a[format_profile]
	else
		:  #  No audio tracks – nothing to set.
	fi
	return 0
}


gather_info_audio_is_lossless() {
	if [  -v source_a[format]  ]; then
		local lossless_format_list=$(
		          IFS='|';  echo "${known_audio_lossless_formats[*]}"
		      )
		shopt -s nocasematch
		[[ ${source_a[format]} =~ ^($lossless_format_list)$ ]]  \
			&& source_a[is_lossless]=t
		shopt -u nocasematch
	else
		:  #  No audio tracks – nothing to set.
	fi
	return 0
}


gather_info_audio_stream_size_by_extraction_B() {
	[ -v source_a[stream_size_by_extraction_B]  ] && return 0
	(( source_c[audio_streams_count] == 0 )) && return 0
	local raw_stream="$TMPDIR/aud.raw"
	rm -f "$raw_stream"
	#  Assuming, that webms that we test all have audio track AFTER the video,
	#  i.e. that the audio stream has id 1 (video stream id is 0). Mkvextract
	#  operates on the whole bunch of streams without subdivision by kind.
	mkvextract "${source[path]}" tracks --fullraw "1:$raw_stream"  &>/dev/null
	source_a[stream_size_by_extraction_B]=$( stat -c %s "$raw_stream" )
	[[ "${source_a[stream_size_by_extraction_B]}" =~ ^[0-9]+$ ]]  \
		|| unset source_a[stream_size_by_extraction_B]
	return 0
}


gather_info_audio_bitrate_by_extraction() {
	[ -v source_a[bitrate_by_extraction]  ] && return 0
	gather_info_audio_stream_size_by_extraction_B
	[ -v source_a[stream_size_by_extraction_B]  ] || return 0
	[ -v source_c[duration_total_s_ms]  ] || return 0
	source_a[bitrate_by_extraction]=$((
		  source_a[stream_size_by_extraction_B]
		* 8
		/ ${source_c[duration_total_s_ms]%\.*}
	))
	return 0
}

 # May be needed in the future.
#
# gather_info_audio_codec_id() {
# 	if [  -v source_a[external_file]  ]; then
# 		__gather_audio_info_check_for_external_file
# 		source_a[codec_id]=$(
# 			${xml[@]} '//x:track[@type="Audio"]/x:CodecID'  \
# 				<<<"${source_a[external_file_mediainfo]}"
# 		)
# 	elif (( source_c[audio_streams_count] > 0 )); then
# 		__gather_audio_info_set_track_specifier
# 		source_a[codec_id]=$(
# 			${xml[@]} "//x:track[@type=\"Audio\"]${source_a[track_specifier]:-}/x:CodecID"  \
# 				<<<"${source[mediainfo]}"
# 		)
# 	else
# 		:  #  No audio tracks – nothing to set.
# 	fi
# 	return 0
# }
#
#
# gather_info_audio_bitrate_mode() {
# 	if [  -v source_a[external_file]  ]; then
# 		__gather_audio_info_check_for_external_file
# 		source_a[bitrate_mode]=$(
# 			${xml[@]} '//x:track[@type="Audio"]/x:BitRate_Mode'  \
# 				<<<"${source_a[external_file_mediainfo]}"
# 		)
# 	elif (( source_c[audio_streams_count] > 0 )); then
# 		__gather_audio_info_set_track_specifier
# 		source_a[bitrate_mode]=$(
# 			${xml[@]} "//x:track[@type=\"Audio\"]${source_a[track_specifier]:-}/x:BitRate_Mode"  \
# 				<<<"${source[mediainfo]}"
# 		)
# 	else
# 		:  #  No audio tracks – nothing to set.
# 	fi
# 	return 0
# }


gather_info_audio_bitrate() {
	if [  -v source_a[external_file]  ]; then
		__gather_audio_info_check_for_external_file
		source_a[bitrate]=$(
			${xml[@]} '//x:track[@type="Audio"]/x:BitRate'  \
				<<<"${source_a[external_file_mediainfo]}"
		) || true
	elif (( source_c[audio_streams_count] > 0 )); then
		__gather_audio_info_set_track_specifier
		source_a[bitrate]=$(
			${xml[@]} "//x:track[@type=\"Audio\"]${source_a[track_specifier]:-}/x:BitRate"  \
				<<<"${source[mediainfo]}"
		) || true
	else
		:  #  No audio tracks – nothing to set.
	fi
	#  Check
	[[ "${source_a[bitrate]}" =~ ^[0-9]+$ ]]  || unset source_a[bitrate]
	return 0
}


gather_info_audio_channels() {
	if [  -v source_a[external_file]  ]; then
		__gather_audio_info_check_for_external_file
		source_a[channels]=$(
			${xml[@]} '//x:track[@type="Audio"]/x:Channels'  \
				<<<"${source_a[external_file_mediainfo]}"
		) || true
	elif (( source_c[audio_streams_count] > 0 )); then
		__gather_audio_info_set_track_specifier
		source_a[channels]=$(
			${xml[@]} "//x:track[@type=\"Audio\"]${source_a[track_specifier]:-}/x:Channels"  \
				<<<"${source[mediainfo]}"
		) || true
	else
		:  #  No audio tracks – nothing to set.
	fi
	#  Check
	[[ "${source_a[channels]}" =~ ^[0-9]+$ ]]  || unset source_a[channels]
	return 0
}


 # May be needed in the future.
#
# gather_info_audio_sampling_rate() {
# 	if [  -v source_a[external_file]  ]; then
# 		__gather_audio_info_check_for_external_file
# 		source_a[sampling_rate]=$(
# 			${xml[@]} '//x:track[@type="Audio"]/x:SamplingRate'  \
# 				<<<"${source_a[external_file_mediainfo]}"
# 		)
# 	elif (( source_c[audio_streams_count] > 0 )); then
# 		__gather_audio_info_set_track_specifier
# 		source_a[sampling_rate]=$(
# 			${xml[@]} "//x:track[@type=\"Audio\"]${source_a[track_specifier]:-}/x:SamplingRate"  \
# 				<<<"${source[mediainfo]}"
# 		)
# 	else
# 		:  #  No audio tracks – nothing to set.
# 	fi
# 	return 0
# }
#
#
# gather_info_audio_bit_depth() {
# 	if [  -v source_a[external_file]  ]; then
# 		__gather_audio_info_check_for_external_file
# 		source_a[bit_depth]=$(
# 			${xml[@]} '//x:track[@type="Audio"]/x:BitDepth'  \
# 				<<<"${source_a[external_file_mediainfo]}"
# 		)
# 	elif (( source_c[audio_streams_count] > 0 )); then
# 		__gather_audio_info_set_track_specifier
# 		source_a[bit_depth]=$(
# 			${xml[@]} "//x:track[@type=\"Audio\"]${source_a[track_specifier]:-}/x:BitDepth"  \
# 				<<<"${source[mediainfo]}"
# 		)
# 	else
# 		:  #  No audio tracks – nothing to set.
# 	fi
# 	return 0
# }



              #  Subtitle stream / subtitle external file info  #

 # Setting track specifier
#  This is a track ID that mediainfo marks each stream of the same type with,
#  like the FFmpeg s:0, s:1 etc.
#  See description to __gather_audio_info_set_track_specifier()
#
__gather_subtitle_info_set_track_specifier() {
	#  Already set? Nothing to do.
	[  -v source_s[track_specifier]  ] && return 0
	#  Finally, if we use a built-in subtitle track, we need to know, if there
	#    is only one – then “typeorder” attribute won’t be there, – or there are
	#    2+, in which case “typeorder” will be present.
	#  Typeorder values in the mediainfo output start from 1, i.e. if there
	#    would be two audio tracks, they would have numbers “1” and “2”.
	#    Contrary to that, ffmpeg – and the source_a[track_id] follow 0-based
	#    order. Both mediainfo and ffmpeg refer to the number of the track
	#    among its kind, audio in this case.
	(( source_c[subtitle_streams_count] > 1 ))  && {
		source_s[track_specifier]="[@typeorder=\"$(( ${source_s[track_id]:-0} +1 ))\"]"
		source_s[ffmpeg_track_specifier]="${source_s[track_id]:-0}"  #  Sic!
	}
	return 0
}


 # Since FFmpeg does differentiate between subrip and vtt subtitles,
#    and mediainfo reports them both as just “UTF-8”, I am going to write
#    it myself – the love story of Mediainfo and cocks.
#  That seems unwise to not separate them, because vtt may develop into some-
#    thing like ass one day. In the videos downloaded from YouTube vtt subs
#    already have a style section. Try this ID: xlCfdggC1fI.
#
gather_info_subtitle_codec() {
	if [  -v source_s[external_file]  ]; then
		local subs_mimetype=$(mimetype -L -b -d "${source_s[external_file]}")
		case "$subs_mimetype" in
			'SSA subtitles')
				;&
			'ASS subtitles')
				# source[s_format]='ASS/SSA'
				source_s[codec]='ass'
				;;
			'WebVTT subtitles')
				# source[s_format]='SubRip/WebVTT'
				source_s[codec]='webvtt'
				;;
			'SubRip subtitles')
				# source[s_format]='SubRip/WebVTT'
				source_s[codec]='subrip'
				;;
			#'<bitmap subtitles in general>')
				#  Bitmap subtitles technically can be rendered, but:
				#  - it is unclear how to identify them properly;
				#  - VobSub subtitles extract as two files – an .idx file
				#    and a .sub file. There’s no example how to use -map
				#    on them;
				#  Thus, unless there’s a precedent, VobSub as external
				#  files won’t be supported, a workaround may be building
				#  them into a mkv (a simply stream copy would do, and
				#  it would be fast), then Nadeshiko can overlay them,
				#  when they are included as a stream.
				#;;
			*)
				unset source_s[codec]
				source_s[mimetype]=$subs_mimetype
				;;
		esac

	elif (( source_c[subtitle_streams_count] > 0 )); then
		__gather_subtitle_info_set_track_specifier
		source_s[codec]=$(
			get_ffmpeg_attribute "${src[path]}"  \
			                     "s:${source_s[ffmpeg_track_specifier]:-0}"  \
			                     codec_name
		)

	else
		:  #  No subtitle tracks – nothing to set.
	fi

	return 0
}


return 0