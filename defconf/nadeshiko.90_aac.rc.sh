#  nadeshiko.90_aac.rc.sh
#
#  Parameters for encoding with FFmpeg’s built-in aac audio codec.
#  Only CBR.



 # Nadeshiko will try to use a higher acodec profile, than the one specified
#    in the bitres profile, if there would be enough space (calculated by the
#    average bitrate, represented in the array index below).
#  FFmpeg wiki puts native aac implementation below libfdk_aac in terms
#    of quality: https://trac.ffmpeg.org/wiki/Encode/HighQualityAudio
#    At the same time “man ffmpeg-codecs” states, that “Its quality is on par
#    or better than libfdk_aac at the default bitrate of 128kbps”. For these
#    two reasons the lowest bitrate border is lifted to 112k.
#  Settings for the aac codec use CBR, because all that is known about VBR
#    in this implementation, is these two points:
#    - “Effective range for -q:a is around 0.1-2”;
#    - “This VBR is experimental and likely to get even worse results
#      than the CBR”. — FFmpeg wiki/HQaudio
#  AAC is technically developed with the same aims as Opus, and sometimes
#    used as Opus. This tells, that AAC bitrates may go below 96 kbps (what’s
#    served from Twitter sometimes has 66 kbps), however: a) their codec may
#    differ; b) they may just don’t care about quality at all; and c) it needs
#    tests, tests, tests. And somebody with good ears.
#
aac_profiles=(
	[196]="-b:a 196k"
	[160]="-b:a 160k"
	[128]="-b:a 128k"  #  Recommended by FFmpeg wiki.
	[112]="-b:a 112k"  #  Assumed lowest usable bitrate.
	                   #    FFmpeg wiki must be referring to HE-AAC in
	                   #    > usable range ≥ 32Kbps (depending on profile
	                   #      and audio)
)


bitres_profile_360p+=(
	[aac_profile]=112
)

bitres_profile_480p+=(
	[aac_profile]=112
)

bitres_profile_576p+=(
	[aac_profile]=112
)

bitres_profile_720p+=(
	[aac_profile]=112
)

bitres_profile_1080p+=(
	[aac_profile]=128
)

bitres_profile_1440p+=(
	[aac_profile]=128
)

bitres_profile_2160p+=(
	[aac_profile]=128
)


 # Size deviations
#  [for clip with <= this duration seconds will be applied]="this deviaton"
#  Deviations are expressed in seconds of playback at the current bitrate
#  (it’s the profile in the name of the variable) to be used as padding when
#  Nadeshiko calculates space requried for tracks.
#
aac_112_size_deviations_per_duration=(
	[3]=.0125
	[10]=.0182
	[30]=.0395
	[60]=.0782
	[240]=.2722
)

aac_128_size_deviations_per_duration=(
	[3]=.0097
	[10]=.0147
	[30]=.0332
	[60]=.0792
	[240]=.3180
)

aac_160_size_deviations_per_duration=(
	[3]=.0135
	[10]=.0400
	[30]=.0567
	[60]=.0967
	[240]=.2685
)

aac_196_size_deviations_per_duration=(
	[3]=.0080
	[10]=.0262
	[30]=.0530
	[60]=.1752
	[240]=.5092
)

#  FFmpeg libavcodec 58.52.101 / 58.52.101