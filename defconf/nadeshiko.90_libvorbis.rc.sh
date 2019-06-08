#  nadeshiko.90_libvorbis.rc.sh
#
#  Parameters for encoding with libvorbis audio codec.
#  Only VBR.



 # Nadeshiko will try to use a higher acodec profile, than the one specified
#    in the bitres profile, if there would be enough space (calculated by the
#    average bitrate, represented in the array index below).
#  Libvorbis controls varaible bitrate with the quality setting, and though
#    there are specific options to set minimum and maximum bitrates, there is
#    no guide or recommendation on what these should be for a given quality.
#
libvorbis_profiles=(
	[192]="-aq 6"
	[160]="-aq 5"
	[128]="-aq 4"  #  Recommended by FFmpeg wiki
	[112]="-aq 3"
	[96]=" -aq 2"  #  Lowest usable by FFmpeg wiki

	#  FFmpeg wiki restricts bottom usable range with 96k
	#  https://trac.ffmpeg.org/wiki/Encode/HighQualityAudio
)


bitres_profile_360p+=(
	[libvorbis_profile]=96
)

bitres_profile_480p+=(
	[libvorbis_profile]=96
)

bitres_profile_576p+=(
	[libvorbis_profile]=112
)

bitres_profile_720p+=(
	[libvorbis_profile]=112
)

bitres_profile_1080p+=(
	[libvorbis_profile]=128
)

bitres_profile_1440p+=(
	[libvorbis_profile]=128
)

bitres_profile_2160p+=(
	[libvorbis_profile]=128
)


 # Size deviations
#  [for clip with <= this duration seconds will be applied]="this deviaton"
#  Deviations are expressed in seconds of playback at the current bitrate
#  (it’s the profile in the name of the variable) to be used as padding when
#  Nadeshiko calculates space requried for tracks.
#
libvorbis_96_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0025
	[30]=.0025
	[60]=.0025
	[240]=.0025
)

libvorbis_112_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0025
	[30]=.0025
	[60]=.0025
	[240]=.0025
)

libvorbis_128_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0435
	[30]=.0025
	[60]=.0025
	[240]=.0025
)

libvorbis_160_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0025
	[30]=.0025
	[60]=.0025
	[240]=.0025
)

libvorbis_192_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0025
	[30]=.0025
	[60]=.0025
	[240]=.0025
)


#  Libvorbis 1.3.6, FFmpeg libavcodec 58.52.101 / 58.52.101