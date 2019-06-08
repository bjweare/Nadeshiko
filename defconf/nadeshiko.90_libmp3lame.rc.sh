#  nadeshiko.90_libmp3lame.rc.sh
#
#  Parameters for encoding with libmp3lame audio codec.
#  Only VBR.



 # Setting compression level.
#  0..9, the lower the value, the higher the quality and the slower is
#    the encode. (Seems to be set to 0 by default.)
#
libmp3lame_common_options="-compression_level 0"


 # Nadeshiko will try to use a higher acodec profile, than the one specified
#    in the bitres profile, if there would be enough space (calculated by the
#    average bitrate, represented in the array index below).
#  FFmpeg wiki puts libmp3lame after Opus, Vorbis and AAC codecs in terms
#    of quality, so using it is not recommended. It’s here only as a fallback
#    for (half-)broken FFmpeg installations.
#    https://trac.ffmpeg.org/wiki/Encode/HighQualityAudio
#  Recommendations are taken from the Hydrogen audio wiki:
#    http://wiki.hydrogenaud.io/index.php?title=LAME#Recommended_encoder_settings
#    and conversion of “lame” -V option values to ffmpeg -aq is taken from
#    the FFmpeg wiki https://trac.ffmpeg.org/wiki/Encode/MP3
#
libmp3lame_profiles=(
	[245]="$libmp3lame_common_options -aq 0"  # 220–260k
	[225]="$libmp3lame_common_options -aq 1"  # 190–250k
	[190]="$libmp3lame_common_options -aq 2"  # 170–210k. Highest recommended.
	[175]="$libmp3lame_common_options -aq 3"  # 150–195k
	[165]="$libmp3lame_common_options -aq 4"  # 140–185k
	[130]="$libmp3lame_common_options -aq 5"  # 120–150k
	[115]="$libmp3lame_common_options -aq 6"  # 100–130k. Lowest recommended.
)


 # CBR variant for the reference.
#  Note, that with libmp3lame the values for -b:a  are fixed and must be
#  taken from 16 possible values.
#
# libmp3lame_profiles=(
# 	[256]="-b:a 256k"
# 	[224]="-b:a 224k"
# 	[192]="-b:a 192k"  # Highest recommended.
# 	[160]="-b:a 160k"
# 	[128]="-b:a 128k"  # Lowest recommended.
# )


bitres_profile_360p+=(
	[libmp3lame_profile]=115
)

bitres_profile_480p+=(
	[libmp3lame_profile]=130
)

bitres_profile_576p+=(
	[libmp3lame_profile]=165
)

bitres_profile_720p+=(
	[libmp3lame_profile]=175
)

bitres_profile_1080p+=(
	[libmp3lame_profile]=190
)

bitres_profile_1440p+=(
	[libmp3lame_profile]=190
)

bitres_profile_2160p+=(
	[libmp3lame_profile]=190
)


 # Size deviations
#  [for clip with <= this duration seconds will be applied]="this deviaton"
#  Deviations are expressed in seconds of playback at the current bitrate
#  (it’s the profile in the name of the variable) to be used as padding when
#  Nadeshiko calculates space requried for tracks.
#
libmp3lame_115_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0805
	[30]=.3887
	[60]=.6900
	[240]=.0025
)

libmp3lame_130_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0900
	[30]=.4362
	[60]=.6455
	[240]=.0025
)

libmp3lame_165_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0025
	[30]=.0025
	[60]=.0025
	[240]=.0025
)

libmp3lame_175_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0025
	[30]=.0925
	[60]=.0025
	[240]=.0025
)

libmp3lame_190_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0062
	[30]=.2210
	[60]=.3980
	[240]=.0025
)

libmp3lame_225_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0025
	[30]=.1832
	[60]=.3902
	[240]=.0025
)

libmp3lame_245_size_deviations_per_duration=(
	[3]=.0025
	[10]=.1215
	[30]=.6737
	[60]=1.3827
	[240]=.0025
)


#  Lame 3.100, FFmpeg libavcodec 58.52.101 / 58.52.101