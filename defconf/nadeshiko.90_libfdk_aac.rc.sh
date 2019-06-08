#  nadeshiko.90_libfdk_aac.rc.sh
#
#  Parameters for encoding with Fraunhofer FDK AAC audio codec.
#  By default, VBR where possible, otherwise CBR. All-CBR is an option.



 # Which profile table to use.
#  “cbr” or “vbr”.
#
#  libfdk_aac adjust the highest possible frequency of the sound (do not con-
#    fuse this with sample rate) depending on the bitrate setting in effect:
#    - at -vbr 5 the frequencies are *not* cut;
#    - at -vbr 4 the frequencies are cut on 15500 Hz;
#    - at -vbr 3 they would be cut to 14620 Hz, but Nadeshiko uses CBR
#      for that bitrate, see below;
#    - for all CBR bitrates starting at 96k the frequencies are cut
#      on 17000 Hz (and this is the lowest bitrate that Nadeshiko uses).
#  High frequencies are somewhat of a rich property for a lossy sound. Cutting
#    frequencies at 14–15 kHz saves space to better convey the sound in the
#    medium band, while the loss is not that significant. When the bitrates go
#    down However, if you spot that cutting
#    frequencies harms the sound more than bitrate, you can add “-cutoff 18000”
#    to the profile options (it’s the next blocks) in order to avoid the loss.
#  http://wiki.hydrogenaud.io/index.php?title=Fraunhofer_FDK_AAC#VBR_Modes
#
#  The “-cutoff” option may be used with libvorbis,
#
libfdk_aac_mode='vbr'


 # Nadeshiko will try to use a higher acodec profile, than the one specified
#    in the bitres profile, if there would be enough space (calculated by the
#    average bitrate, represented in the array index below).
#  FFmpeg wiki puts libfdk_aac as “lower or equal” to libvorbis in the terms
#    of quality, so it uses libvorbis bitrate settings.
#    https://trac.ffmpeg.org/wiki/Encode/HighQualityAudio
#
libfdk_aac_cbr_profiles=(
	[192]="-b:a 192k"
	[160]="-b:a 160k"
	[128]="-b:a 128k"  #  Recommended by FFmpeg wiki
	[112]="-b:a 112k"
	[96]=" -b:a  96k"  #  Lowest usable by FFmpeg wiki
)


 # VBR equivalent encoding options
#  When libfdk_aac_mode is set to “vbr”, items from this array replace
#    the corresponding items in libfdk_profiles.
#  The -vbr option has only five values, of which the first two are of no
#    interest, because if libfdk_aac is equaled to libvorbis, and the usable
#    range of the latter starts at 96k (2 channels, 48k per channel) – as the
#    wiki itself says – then the bitrates lower than 96k seem to be
#    not suiting for use.
#    http://wiki.hydrogenaud.io/index.php?title=Fraunhofer_FDK_AAC#Bitrate_Modes
#  AAC is technically developed with the same aims as Opus, and sometimes
#    used as Opus. This tells, that AAC bitrates may go below 96 kbps (what’s
#    served from Twitter sometimes has 66 kbps), however: a) their codec may
#    differ; b) they may just don’t care about quality at all; and c) it needs
#    tests, tests, tests. And somebody with good ears.
#
libfdk_aac_vbr_profiles=(
	[192]="-vbr   5"
	[160]="-b:a 160k"  # CBR substitution for the lacking -vbr option
	[128]="-vbr   4"
	[112]="-b:a 112k"  # CBR substitution for the lacking -vbr option
	[96]=" -b:a  96k"  # CBR is preferred over “-vbr 3”, for at long durations
	                   #   libfdk_aac overshoots on 7 seconds which is an equi-
	                   #   valent for 2–3 seconds of video playback @360p.
	                   #   Being precise to size is more important here.
)


 # If you want to switch to CBR profiles, set libfdk_aac_mode=cbr in your
#  config and copy this line there as is.
#
declare -n libfdk_aac_profiles="libfdk_aac_${libfdk_aac_mode}_profiles"


bitres_profile_360p+=(
	[libfdk_aac_profile]=96
)

bitres_profile_480p+=(
	[libfdk_aac_profile]=96
)

bitres_profile_576p+=(
	[libfdk_aac_profile]=112
)

bitres_profile_720p+=(
	[libfdk_aac_profile]=112
)

bitres_profile_1080p+=(
	[libfdk_aac_profile]=128
)

bitres_profile_1440p+=(
	[libfdk_aac_profile]=128
)

bitres_profile_2160p+=(
	[libfdk_aac_profile]=128
)


 # Size deviations
#  [for clip with <= this duration seconds will be applied]="this deviaton"
#  Deviations are expressed in seconds of playback at the current bitrate
#  (it’s the profile in the name of the variable) to be used as padding when
#  Nadeshiko calculates space requried for tracks.
#
libfdk_aac_96_size_deviations_per_duration=(
	[3]=.0317
	[10]=.0330
	[30]=.0367
	[60]=.0352
	[240]=.0320
)

libfdk_aac_112_size_deviations_per_duration=(
	[3]=.0272
	[10]=.0262
	[30]=.0310
	[60]=.0272
	[240]=.0257
)

libfdk_aac_128_size_deviations_per_duration=(
	[3]=.0107
	[10]=.0025
	[30]=1.9740
	[60]=3.8097
	[240]=2.6867
)

 # For CBR profiles
#
# libfdk_aac_128_size_deviations_per_duration=(
# 	[3]=.0255
# 	[10]=.0242
# 	[30]=.0290
# 	[60]=.0250
# 	[240]=.0225
# )

libfdk_aac_160_size_deviations_per_duration=(
	[3]=.0227
	[10]=.0215
	[30]=.0252
	[60]=.0227
	[240]=.0200
)

libfdk_aac_192_size_deviations_per_duration=(
	[3]=.1107
	[10]=.4530
	[30]=2.2345
	[60]=3.6370
	[240]=9.5957
)

 # For CBR profiles
#
# libfdk_aac_192_size_deviations_per_duration=(
# 	[3]=.0202
# 	[10]=.0190
# 	[30]=.0222
# 	[60]=.0200
# 	[240]=.0200
# )


#  libfdk-aac 2.0.0, FFmpeg libavcodec 58.52.101 / 58.52.101