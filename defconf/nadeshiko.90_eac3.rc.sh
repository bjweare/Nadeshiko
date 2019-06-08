#  nadeshiko.90_eac3.rc.sh
#
#  Parameters for encoding with eac3 audio codec.



 # Nadeshiko will try to use a higher acodec profile, than the one specified
#    in the bitres profile, if there would be enough space (calculated by the
#    average bitrate, represented in the array index below).
#  FFmpeg wiki estimates the quality, that eac3 encoder produces, as equal
#    or inferior to libmp3lame, so using it is not recommended. It’s here only
#    as a fallback for (half-)broken FFmpeg installations.
#    https://trac.ffmpeg.org/wiki/Encode/HighQualityAudio
#  Few is known about the differences between ac3 and eac3 codecs. These set-
#    tings copy ac3, though the bitrate requirements are supposed to be lower
#    than for ac3, because E-AC-3 should have some improvements, that reduce
#    artefacts. Or at least Wikipedia says so.
#  See nadeshiko.90_ac3.rc.sh for more details on ac3.
#
eac3_profiles=(
	[256]="-b:a 256k"
	[224]="-b:a 224k"
	[192]="-b:a 192k"
	[160]="-b:a 160k"  # Lowest and recommended.
)


bitres_profile_360p+=(
	[eac3_profile]=160
)

bitres_profile_480p+=(
	[eac3_profile]=160
)

bitres_profile_576p+=(
	[eac3_profile]=192
)

bitres_profile_720p+=(
	[eac3_profile]=192
)

bitres_profile_1080p+=(
	[eac3_profile]=192
)

bitres_profile_1440p+=(
	[eac3_profile]=192
)

bitres_profile_2160p+=(
	[eac3_profile]=192
)


 # Size deviations
#  [for clip with <= this duration seconds will be applied]="this deviaton"
#  Deviations are expressed in seconds of playback at the current bitrate
#  (it’s the profile in the name of the variable) to be used as padding when
#  Nadeshiko calculates space requried for tracks.
#
eac3_160_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0050
	[30]=.0050
	[60]=0
	[240]=.0100
)

eac3_192_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0050
	[30]=.0050
	[60]=0
	[240]=.0100
)

eac3_224_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0050
	[30]=.0050
	[60]=0
	[240]=.0100
)

eac3_256_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0050
	[30]=.0050
	[60]=0
	[240]=.0100
)


#  FFmpeg libavcodec 58.52.101 / 58.52.101