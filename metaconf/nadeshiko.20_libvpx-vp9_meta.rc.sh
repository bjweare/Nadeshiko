#  nadeshiko.20_libvpx-vp9_meta.rc.sh



 # Formats, that this codec is known as, e.g. “AVC” for libx264.
#  Knowing the format of the source is essential to estimate what quality
#    does the source video bitrate provide and whether certain bitrate
#    bumps would make sence, when Nadeshiko will re-encode the video.
#  Type: array.
#  Item example: <the value of the “Format” field for video stream,
#                 as reported by mediainfo>
#
vcodec_name_as_formats_libvpx_vp9=(
	'VP9'
)


 # Working combinations of containers and audio/video codecs.
#  One string represents a working combination. When $container is set
#    to “auto” in the user’s config or in nadeshiko.10_main.rc.sh, the first
#    item, that has $ffmpeg_acodec,  would be picked.
#  Type: regular array.
#  Item example: 'container  audio_codec'  (as named in ffmpeg,
#                                           the order is free)
#
libvpx_vp9_muxing_sets=(
	'webm libopus'
	'webm libvorbis'
	#  No mkv, because browsers download it instead of playing.
)

RCFILE_BOOLEAN_VARS+=(
	libvpx_vp9_adaptive_tile_columns
)

RCFILE_STRIPUNIT_VARS+=(
	[libvpx_vp9_container_own_size_pct]='%'
	[libvpx_vp9_minimal_bitrate_pct]='%'
	[libvpx_vp9_minsection_pct]='%'
	[libvpx_vp9_maxsection_pct]='%'
	[libvpx_vp9_overshoot_pct]='%'
	[libvpx_vp9_undershoot_pct]='%'
	[libvpx_vp9_bias_pct]='%'
)