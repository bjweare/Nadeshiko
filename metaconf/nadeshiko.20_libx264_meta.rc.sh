#  nadeshiko.20_libx264_meta.rc.sh



 # Formats, that this codec is known as, e.g. “AVC” for libx264.
#  Knowing the format of the source is essential to estimate what quality
#    does the source video bitrate provide and whether certain bitrate
#    bumps would make sence, when Nadeshiko will re-encode the video.
#  Type: array.
#  Item example: <the value of the “Format” field for video stream,
#                 as reported by mediainfo>
#
vcodec_name_as_formats_libx264=(
	'AVC'
)


 # Working combinations of containers and audio/video codecs.
#  One string represents a working combination. When $container is set
#    to “auto” in the user’s config or in nadeshiko.10_main.rc.sh, the first
#    item, that has $ffmpeg_acodec,  would be picked.
#  Type: regular array.
#  Item example: 'container  audio_codec'  (as named in ffmpeg,
#                                           the order is free)
#
libx264_muxing_sets=(
	'mp4 libfdk_aac'
	'mp4 aac'
	'mp4 libmp3lame'
	'mp4 eac3'
	'mp4 ac3'
	#  'mp4 libx264 libopus'  # libopus in mp4 is still experimental
	#                         # and browsers can’t play opus in mp4 anyway
	#  No mkv, because browsers download it instead of playing.
)


RCFILE_STRIPUNIT_VARS+=(
	[libx264_container_own_size_pct]='%'
	[libx264_minimal_bitrate_pct]='%'
)