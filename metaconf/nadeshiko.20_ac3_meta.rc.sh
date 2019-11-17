#  nadeshiko.20_ac3_meta.rc.sh



 # Formats, that this codec is known as, e.g. “Opus” for libopus, “AAC:LC”
#    for AAC (to distinguish from AAC:HE). Format profile, if specified,
#    serves to determine the variation of the encoded audio stream.
#  Knowing the format of the source is essential to estimate what quality
#    does the source video bitrate provide and whether certain bitrate
#    bumps would make sence, when Nadeshiko will re-encode the video.
#  Type: array.
#  Item example: "<Format>[<delimiter><Format profile>]".
#    The values for Format and Format profile are those reported by mediainfo.
#    The delimiter, if used, must be specified via the variable
#    acodec_delimiter_for_name_as_formats_AUDIOCODECNAME.
#
acodec_name_as_formats_ac3=(
	'AC-3'
)

acodec_delimiter_for_name_as_formats_ac3=':'