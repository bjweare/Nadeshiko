#  nadeshiko.90_libx264.rc.sh
#
#  Parameters for encoding with libx264 video codec.



                         #  libx264 options     #
                        #  for advanced users  #
                                              #   wiki: https://git.io/fhSkC

 # Bitrate-resolution profiles
#                                   Read on the wiki
#                                   - what profiles do: https://git.io/fxJhR
#                                   - how profiles work: https://git.io/fxJpu
#
#  Sometimes, the encoded file wouldn’t fit into the maximum size – its reso-
#    lution and/or bitrate may be too big for the required size. The higher is
#    the resolution, the bigger video bitrate it should have. It’s impossible
#    to fit 1 minute of dynamic 1080p into 10 megabytes, for example. A lower
#    resolution, however – 720p for example, would need less bitrate,
#    so it may fit!
#  Nadeshiko will calculate the bitrate, that would fit into the requested
#    file size, and then will try to find an appropriate resolution for it.
#    If it could be the native resolution, Nadeshiko will not scale.
#    Otherwise, to avoid making an artefact-ridden clip from a 1080p video
#    for example, Nadeshiko will make a clean one, but in a lower resolution.
#  For each resolution, desired and minimal video bitrates are calculated.
#    Desired is the upper border, which will be tried first, then attempts
#    will go down to the lower border, the minimal value. Steps are in 100k.
#    If the maximum fitting bitrate wasn’t in the range of the resolution,
#    the next will be tried.
#
#
 # The lower border when seeking for the TARGET video bitrate.
#  Calculated as a percentage of the desired bitrate. Highly depends
#    on CPU time, that encoder spends. If you speed up the encoding
#    by putting laxed values in libx264_preset or libvpx_pass*_cpu_used,
#    you should rise the percentage here.
#  Don’t confuse with libvpx_minrate and libvpx_maxrate.
#  Default value: 60
#
libx264_minimal_bitrate_pct='60%'


bitres_profile_360p+=(
	[libx264_desired_bitrate]=500k
)

bitres_profile_480p+=(
	[libx264_desired_bitrate]=1000k
)

bitres_profile_576p+=(
	[libx264_desired_bitrate]=1500k
)

bitres_profile_720p+=(
	[libx264_desired_bitrate]=2000k
)

bitres_profile_1080p+=(
	[libx264_desired_bitrate]=3500k
)

#  Experimental.
bitres_profile_1440p+=(
	[libx264_desired_bitrate]=11900k
)

#  Experimental.
bitres_profile_2160p+=(
	[libx264_desired_bitrate]=23900k
)


 # Colourspace, chroma subsampling and number of bits per colour.
#  Possible values: everything that “ffmpeg -hide_banner -h encoder=libx264”
#    mentions in the “Supported pixel formats”.
#  Recommended value: yuv420p (browsers poorly support higher chroma
#    and do not support 10bit colour).
#  Default value: 'yuv420p'
#
libx264_pix_fmt='yuv420p'


 # Speed / quality preset
#  “veryslow” > “slower” > “slow” > shit > “medium” > … > “ultrafast”.
#
libx264_preset='veryslow'


 # Preset tune. Less significant than the preset itself
#  “animation” / “film” > shit > “fastdecode” > “zerolatency”.
#  “animation” ≈ “film” + more B-frames.
#
libx264_tune='animation'


 # Profile enables encoding features. A decoder must also support them
#  in order to play the video
#  high444p > high10 > high > main > baseline
#  Browsers do not support high10 or high444p.
#
libx264_profile='high'


 # Video codec profile level
#  Higher profiles optimise bitrate better.
#  Very old devices may require level 3.0 and baseline profile.
#
libx264_level='4.2'


 # Keyframe interval
#  The shorter it is, the more key frames the encoded video will have.
#  Recommended values depend on several factors, but 50 should be OK
#    for the most short videos. It places a key frame every ≈2 seconds.
#  - the more short and dynamic the video is (drastic scene changes within
#    seconds), the more keyframes it needs. 25–100.
#  - the longer is the video and the harder Nadeshiko tries to fit it in the
#    given filesize, the more keyframes it needs. 25–50.
#  - only if you encode large videos (entire episodes or films), and do not
#    limit the file size, keyframes may be relaxed. 450–500.
#  Default value: 50
#
libx264_keyint=50


 # Place for user-specified ffmpeg options
#  These will be applied ONLY when used with libx264 as an encoder.
#  Array of strings!  I.e. =(-key value  -other-key "value with spaces")
#
libx264_pass1_extra_options=()
libx264_pass2_extra_options=()
