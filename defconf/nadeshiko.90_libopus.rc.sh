#  nadeshiko.90_libopus.rc.sh
#
#  Parameters for encoding with libopus audio codec.
#  Only VBR.



 # FFmpeg default. Here for clarity.
#
libopus_common_opts='-vbr on  -compression_level 10'


 # Nadeshiko will try to use a higher acodec profile, than the one specified
#  in the bitres profile, if there would be enough space (calculated by the
#  average bitrate, represented in the array index below).
#
libopus_profiles=(
	[192]="$libopus_common_opts -b:a 192k"
	[160]="$libopus_common_opts -b:a 160k"
	[128]="$libopus_common_opts -b:a 128k"  #  Max for music on opus-codec.org
	[112]="$libopus_common_opts -b:a 112k"
	[96]=" $libopus_common_opts -b:a  96k"
	[64]=" $libopus_common_opts -b:a  64k"  #  Recommended by FFmpeg wiki
	[48]=" $libopus_common_opts -b:a  48k"  #  Lowest for music on opus-codec.org

	#  FFmpeg wiki restricts bottom usable range with 32k, but the Opus page
	#  with examples uses a minimum of 48k and maximum of 128k for music.
	#  https://trac.ffmpeg.org/wiki/Encode/HighQualityAudio
	#  http://opus-codec.org/examples/
)


bitres_profile_360p+=(
	[libopus_profile]=48
)

bitres_profile_480p+=(
	[libopus_profile]=64
)

bitres_profile_576p+=(
	[libopus_profile]=96
)

bitres_profile_720p+=(
	[libopus_profile]=112
)

bitres_profile_1080p+=(
	[libopus_profile]=128
)

bitres_profile_1440p+=(
	[libopus_profile]=128
)

bitres_profile_2160p+=(
	[libopus_profile]=128
)


 # Size deviations
#  [for clip with <= this duration seconds will be applied]="this deviaton"
#  Deviations are expressed in seconds of playback at the current bitrate
#  (it’s the profile in the name of the variable) to be used as padding when
#  Nadeshiko calculates space requried for tracks.
#
libopus_48_size_deviations_per_duration=(
	[3]=.0412
	[10]=.0025
	[30]=.0025
	[60]=.0025
	[240]=.0025
)

libopus_64_size_deviations_per_duration=(
	[3]=.2075
	[10]=.1205
	[30]=.0025
	[60]=.0025
	[240]=.0025
)

libopus_96_size_deviations_per_duration=(
	[3]=.1037
	[10]=.0242
	[30]=.0025
	[60]=.0025
	[240]=.0025
)

libopus_112_size_deviations_per_duration=(
	[3]=.0962
	[10]=.0180
	[30]=.0025
	[60]=.0025
	[240]=.0025
)

libopus_128_size_deviations_per_duration=(
	[3]=.0900
	[10]=.0195
	[30]=.0025
	[60]=.0025
	[240]=.0025
)

libopus_160_size_deviations_per_duration=(
	[3]=.0590
	[10]=.0025
	[30]=.0025
	[60]=.0025
	[240]=.0025
)

libopus_192_size_deviations_per_duration=(
	[3]=.0222
	[10]=.0025
	[30]=.0025
	[60]=.0025
	[240]=.0025
)


#  Opus 1.3.1, FFmpeg libavcodec 58.52.101 / 58.52.101