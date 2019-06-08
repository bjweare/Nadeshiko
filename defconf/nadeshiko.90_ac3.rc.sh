#  nadeshiko.90_ac3.rc.sh
#
#  Parameters for encoding with ac3 audio codec.



 # Nadeshiko will try to use a higher acodec profile, than the one specified
#    in the bitres profile, if there would be enough space (calculated by the
#    average bitrate, represented in the array index below).
#  FFmpeg wiki estimates the quality, that ac3 encoder produces, as equal
#    or inferior to libmp3lame, so using it is not recommended. It’s here only
#    as a fallback for (half-)broken FFmpeg installations.
#    https://trac.ffmpeg.org/wiki/Encode/HighQualityAudio
#  Bitrates here copy a subset of libmp3lame CBR set, because according to the
#    FFmpeg wiki (see the link above) the lowest usable bitrate for ac3 is 160k.
#    Taking into account, that “libmp3lame >= ac3”, the point of sufficient
#    quality (which is used for 1080p and above) should be reached with the
#    same bitrate as with libmp3lame – where it is 192k – or above it. So, des-
#    pite the wiki states 160k as recommended for ac3, 192k is used instead.
#  Actual encoding options for ac3 are unknown, as it is used only in the high-
#    est settings in DVDs and BDs. There, for 6-channel audio a bitrate of 640k
#    is used. If we’d take the formula from FFmpeg wiki for calculation of mul-
#    tichannel audio total bitrate and assume, that these 640k do achieve audio
#    transparency on six chanels, then 640/3 ≈ 213 kbit would be the point of
#    achieving transparently on two-channel audio. 213k bitrate is above the
#    “lowest and recommended” 160k on FFmpeg wiki, and still above 192k, the
#    bitrate below transparency point used in libmp3lame. Makes sense.
#  More information:
#    - http://www.digitalfaq.com/forum/video-conversion/1465-how-encode-audio.html
#    - http://wiki.hydrogenaud.io/index.php?title=AC3
#    - https://github.com/deterenkelt/Nadeshiko/wiki/Sound-in-Nadeshiko#ac3
#
ac3_profiles=(
	[256]="-b:a 256k"
	[224]="-b:a 224k"
	[192]="-b:a 192k"
	[160]="-b:a 160k"  # Lowest and recommended.
)


bitres_profile_360p+=(
	[ac3_profile]=160
)

bitres_profile_480p+=(
	[ac3_profile]=160
)

bitres_profile_576p+=(
	[ac3_profile]=192
)

bitres_profile_720p+=(
	[ac3_profile]=192
)

bitres_profile_1080p+=(
	[ac3_profile]=192
)

bitres_profile_1440p+=(
	[ac3_profile]=192
)

bitres_profile_2160p+=(
	[ac3_profile]=192
)


 # Size deviations
#  [for clip with <= this duration seconds will be applied]="this deviaton"
#  Deviations are expressed in seconds of playback at the current bitrate
#  (it’s the profile in the name of the variable) to be used as padding when
#  Nadeshiko calculates space requried for tracks.
#
ac3_160_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0050
	[30]=.0050
	[60]=0
	[240]=.0100
)

ac3_192_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0050
	[30]=.0050
	[60]=0
	[240]=.0100
)

ac3_224_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0050
	[30]=.0050
	[60]=0
	[240]=.0100
)

ac3_256_size_deviations_per_duration=(
	[3]=.0025
	[10]=.0050
	[30]=.0050
	[60]=0
	[240]=.0100
)


#  FFmpeg libavcodec 58.52.101 / 58.52.101


 # Last patent on this codec has expired only in 2017, so its implementations
#  are expected to be not full or lacking features (why VLC and ffmpeg could
#  have it). Supposedly an echo of this issue is that some features in ac3 en-
#  coder in ffmpeg are not available:
#
#    -dheadphone_mode mode
#      Dolby Headphone Mode. Indicates whether the stream uses Dolby Headphone
#      encoding (multi-channel matrixed to 2.0 for use with headphones). Using
#      this option does NOT mean the encoder will actually apply Dolby Head-
#      phone processing.
#                                                  ― ffmpeg-codecs manual page
#
#
 # 19 allowable bitrates can be found in the ATSC specification:
#  http://www.atsc.org/wp-content/uploads/2015/03/A52-201212-17.pdf, page 117.
#
#
 # Note, that ffmpeg ac3 codec implementation doesn’t have an option,
#  that would represent the most significant bit in “bit_rate_code”, which
#  should determine, whether the bitrate is the constant or only the maximum,
#  that may be reached.