#  nadeshiko.90_libvpx-vp9.rc.sh
#
#  Parameters for encoding with libvpx-vp9 video codec.



                        #  libvpx-vp9 options   #
                       #  for advanced users   #
                                              #   wiki: https://git.io/fhSkW

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
#    will go down to the lower border, the minimal value. If the maximum fit-
#    ting bitrate wasn’t in the range of the resolution, the next will be
#    tried.
#
#
 # The lower border when seeking for the TARGET video bitrate.
#  Calculated as a percentage of the desired bitrate. Highly depends
#    on CPU time, that encoder spends. If you speed up the encoding
#    by putting laxed values in libvpx_pass*_cpu_used, you should raise
#    the percentage here.
#  Don’t confuse with libvpx_minrate and libvpx_maxrate.
#
libvpx_vp9_minimal_bitrate_pct='60%'


bitres_profile_360p+=(
	[libvpx-vp9_desired_bitrate]=276k
	# [libvpx-vp9_min_q]=35
	[libvpx-vp9_max_q]=40
)

bitres_profile_480p+=(
	[libvpx-vp9_desired_bitrate]=750k
	# [libvpx-vp9_min_q]=33
	[libvpx-vp9_max_q]=39
)

bitres_profile_576p+=(
	[libvpx-vp9_desired_bitrate]=888k
	# [libvpx-vp9_min_q]=33
	[libvpx-vp9_max_q]=38
)

bitres_profile_720p+=(
	[libvpx-vp9_desired_bitrate]=1024k
	# [libvpx-vp9_min_q]=32
	[libvpx-vp9_max_q]=37
)

bitres_profile_1080p+=(
	[libvpx-vp9_desired_bitrate]=1800k
	# [libvpx-vp9_min_q]=31
	[libvpx-vp9_max_q]=36
)

#  Experimental.
bitres_profile_1440p+=(
	[libvpx-vp9_desired_bitrate]=6000k
	# [libvpx-vp9_min_q]=24
	[libvpx-vp9_max_q]=34
)

#  Experimental.
bitres_profile_2160p+=(
	[libvpx-vp9_desired_bitrate]=12000k
	# [libvpx-vp9_min_q]=15
	[libvpx-vp9_max_q]=25
)



#  The variables below are used only in the encoding module.

 # Colourspace, chroma subsampling and number of bits per colour.
#  Possible values: everything that “ffmpeg -hide_banner -h encoder=libvpx-vp9”
#    mentions in the “Supported pixel formats”.
#  Recommended value: yuv420p or yuv444p (VP9-capable browsers usually
#    have no troubles playing 4:4:4 chroma).
#
libvpx_vp9_pix_fmt='yuv420p'


 # Tile columns
#  Places an upper constraint on the number of tile-columns,
#  which libvpx-vp9 may use.
#  0–6, must be greater than zero for -threads to work.
#  “Tiling splits the video into rectangular regions, which allows
#   multi-threading for encoding and decoding. The number of tiles
#   is always a power of two. 0=1 tile, 1=2, 2=4, 3=8, 4=16, 5=32.”
#  “Tiling splits the video frame into multiple columns, which slightly
#   reduces quality but speeds up encoding performance. Tiles must be
#   at least 256 pixels wide, so there is a limit to how many tiles
#   can be used.”
#  “Depending upon the number of tiles and the resolution of the output frame,
#   more CPU threads may be useful. Generally speaking, there is limited value
#   to multiple threads when the output frame size is very small.”
#  “The requested tile columns will be capped by encoder based on image size
#   limitation. Tile column width minimum is 256 pixels, maximum is 4096.”
#  The docs on Google Devs recommend to calculate it (see below).
#
libvpx_vp9_tile_columns=6


 # Same as tile-columns, but for rows
#  Usefulness is uncertain, as vpxenc hints, that it’s set to 0 when threads
#  is used: “Number of tile rows to use, log2 (set to 0 while threads > 1)”.
#
#libvpx_vp9_tile_rows


 # Maximum number of CPU threads to use
#  Manual setting. This value is ignored, if $libvpx_vp9_adaptive_tile_columns
#  (below) is set to “yes”.
#
libvpx_vp9_threads=8


 # When enabled, Nadeshiko calculates the values for tile-columns and threads
#  adaptively to the video resolution as the docs on Google Devs recommend:
#  tile-columns = log2(target video width ÷ tile-column minimum width)
#  threads = 2^tile-columns × 2
#
libvpx_vp9_adaptive_tile_columns=yes


 # Frame parallel decodability features
#  “Turns off backward update of probability context”, which supposedly should
#  mean, that B-frames would be based only on their predecessors. This option
#  “allows staged parallel processing of more than one video frames
#  in the decoder”. Spotted to hurt quality in the tests.
#  0 – disable
#  1 – enable
#
libvpx_vp9_frame_parallel=0


 # Encode speed / quality profiles
#
#  --deadline ffmpeg option specifies a profile to libvpx. Profiles are
#     “best” – alike to libx264 “placebo” preset, although this one is
#        not as pointless. FFmpeg wiki, however, warns against that
#        this parameter is misnamed and can produce result worse than “good”.
#     “good” – around “slow”, “slower” and “veryslow”, the optimal range.
#     “realtime” – fast encoding for streaming, poor quality as always.
#        “Setting --good and --cpu-used=0 will give quality that is usually
#        very close to and even sometimes better than that obtained with
#        --best, but the encoder will typically run about twice as fast.”
#
#  --cpu-used tweaks the profiles above. 0, 1 and 2 give best results
#        with “best” and “good” profiles. “Values greater than 0 will in-
#        crease encoder speed at the expense of quality. Changes in this
#        value influences, among others, the encoder’s selection of motion
#        estimation methods.”
#     This is of CRITICAL importance to get better quality. (Though still
#        in order for libvpx to use CPU, corresponding quality constraints
#        must be set first.)
#     −8…8 are the values for VP9 (−16…16 was allowed for VP8).
#        “…settings 0–4 apply for <…> good and best, with 0 being the highest
#        quality and 4 being the lowest. Realtime valid values are 5–8;
#        lower numbers mean higher quality.”
#     Using cpu_used=0 for the first pass didn’t produce any visible
#        differences from when video is encoded with cpu_used=4.
#
#  Changing values here will lower the codec efficiency (details/MiB ratio),
#    so the value in  libvpx_vp9_minimal_bitrate_pct  (see above) will have
#    to be increased.
#
libvpx_vp9_pass1_deadline=good
libvpx_vp9_pass1_cpu_used=4
libvpx_vp9_pass2_deadline=good
libvpx_vp9_pass2_cpu_used=0



 # Frame prefetch for the buffer
#  “Setting auto-alt-ref and lag-in-frames >= 12 will turn on VP9’s alt-ref
#   frames, a VP9 feature that enhances quality.”
#  “When --auto-alt-ref is enabled, the default mode of operation is to either
#   populate the buffer with a copy of the previous golden frame, when this
#   frame is updated, or with a copy of a frame derived from some point
#   of time in the future.”
#
#  “Use of --auto-alt-ref can substantially improve quality in many
#    situations (though there are still a few where it may hurt).” (2016)
#  Research made to compare encodes with auto-alt-ref 1 and 6 revealed that
#    there will be no drastic change for short videos (< 5 seconds), be they
#    dynamic of static, however, longer videos suffer less artefacts with
#    a greater number of reference frames. On the wiki: https://git.io/fjAsM
#  Old devices – 2015/16 and before – have issue playing VP9-encoded videos,
#    if the number of reference frames used was greater than 1.
#
#  Codec default
#    libvpx-1.7:   0 – disabled.
#                  1 – enabled.
#
#    libvpx-1.8:   0 – disabled.
#                  1–6 – higher values help avoid artifacts in dynamic scenes
#                        on low-bitrate videos.
#
libvpx_vp9_auto_alt_ref=6


 # Compatibility for mobile devices
#  As VP9 decoder on smarphones often doesn’t support playback of videos,
#    that were encoded with “--auto-alt-ref 6”, setting this option would
#    order to use less reference frames for short videos.
#  The value is the duration of video, in seconds, below which auto-alt-ref=1
#    will be used instead of auto-alt-ref=6.
#
libvpx_vp9_allow_autoaltref6_only_for_videos_longer_than_sec=30


 # Upper limit on the number of frames into the future,
#  that the encoder can look for --auto-alt-ref.
#  Values are in range 0–25. 25 is the codec default. 16 is recommended
#  by webmproject.org (2016).
#
libvpx_vp9_lag_in_frames=25


 # Maximum interval between key frames (ffmpeg -g).
#  Webmproject.org recommends to use “-g 9999” (2016)
#  VP9 docs on developers.google.com recommend “-g 240” (2017)
#  Whichever you would pass to ffmpeg, the resulting webm would have a key
#  frame on each 95±5th frame.
#
libvpx_vp9_kf_max_dist=9999


 # Isn’t implemented in libvpx-vp9.
#
#libvpx_vp9_kf_min_dist


 # Lower and upper bitrate borders for a GOP, in % from target bitrate.
#  50% and 145% are recommended by the docs on Google Devs.
#
libvpx_vp9_minsection_pct=50
libvpx_vp9_maxsection_pct=145


 # Datarate overshoot (maximum) target (%)
#  How much deviation in size from the target bitrate is allowed.
#  −1…1000, codec default is −1.
#
libvpx_vp9_overshoot_pct=0


 # Datarate undershoot (minimum) target (%)
#  How much deviation in size from the target bitrate is allowed.
#  −1…100, codec default is −1.
#
libvpx_vp9_undershoot_pct=0


 # CBR/VBR bias (0=CBR, 100=VBR)
#  Codec default is unknown. Nadeshiko doesn’t use it by default
#    (but may apply).
#
#libvpx_vp9_bias_pct=0


 # Adaptive quantisation mode
#  Segment based feature, that allows encoder to adaptively change quantisa-
#    tion parameter for each segment within a frame to improve the subjective
#    quality.
#  Never used in examples. Tests have shown, that on poor/fast encodes
#    aq-mode=3 gave a significant quality boost, but on a proper Q values
#    the difference vanes.
#  0 – off (default)
#  1 – variance
#  2 – complexity
#  3 – cyclic refresh
#  4 – equator360
#
libvpx_vp9_aq_mode=0


 # Maximum keyframe bitrate as a percentage of the target bitrate
#  This value controls additional clamping on the maximum size of a keyframe.
#  It is expressed as a percentage of the average per-frame(!) bitrate, with
#  the special (and default) value 0 meaning unlimited, or no additional
#  clamping beyond the codec's built-in algorithm.
#  Nadeshiko currently doesn’t use it.
#
#libvpx_vp9_max_intra_rate


 # Maximum I-frame bitrate as a percentage of the target bitrate
#  This value controls additional clamping on the maximum size of an inter
#  frame. It is expressed as a percentage of the average per-frame bitrate,
#  with the special (and default) value 0 meaning unlimited, or no additional
#  clamping beyond the codec’s built-in algorithm.
#  Nadeshiko currently doesn’t use it; even ffmpeg-san has no option for it w
#
#libvpx_vp9_max_inter_rate


 # Source video type
#  “0” – default type, any video
#  “1” – screen (capture of desktop?)
#  “2” – film (to preserve film grain?), helps to avoid excessive blurriness.
#
libvpx_vp9_tune_content=2


 # Static threshold
#  Should be understood literally: it’s an option to suppress noise on live
#  translations, where real movements are low. Causes regions on image not
#  being updated, which leads to artefacts. If you looked for motion-estima-
#  tion methods, it’s defined by --cpu-used in VP9.
#  “In most scenarios this value should be set to 0.”
#  Nadeshiko doesn’t use this.
#
#libvpx_vp9_static_threshold


 # Commonly assumed to determine the number of bits in chroma and its type.
#  Parameter value: bits per sample; chroma subsampling
#  “0” – 8 bits/sample;         4:2:0
#  “1” – 8 bits/sample;                4:2:2,  4:4:4
#  “2” – 10 or 12 bits/sample;  4:2:0
#  “3” – 10 or 12 bits/sample;         4:2:2,  4:4:4
#
 # The confusing description of profiles on the webmproject website
#  https://www.webmproject.org/docs/encoder-parameters/
#  should be disregarded: refer to the 2016 specification instead:
#  https://storage.googleapis.com/downloads.webmproject.org/docs/vp9/
#  vp9-bitstream-specification-v0.6-20160331-draft.pdf, section 5.19.
#
 # Nadeshiko doesn’t use this option: FFmpeg chooses an appropriate profile
#  automatically based on the  ffmpeg_pix_fmt  option).
#
#libvpx_vp9_profile


 # Determines maximum resolution, bitrate, ref frames etc.
#  For 1080p the minimal value is 4.0
#  https://www.webmproject.org/vp9/levels/
#
libvpx_vp9_level=4.1


 # An optimisation to pass synthetic tests better.
#  SSIM is considered closer to the human eye perception.
#  Values are: “psnr” or  “ssim”
#  SSIM is still not supported in libvpx-1.8.0.
#  > Failed to set VP8E_SET_TUNING codec control: Invalid parameter
#  > Option --tune=ssim is not currently supported.
#
# libvpx_vp9_tune=ssim


 # Row based multi-threading.
#  0 = off, 1 = on.
#  Non-deterministic! two encodes will not be the same.
#  “Rows” refer to the rows of macroblocks within a single tile-column.
#     It shouldn’t be confused with -tile-rows. Yes, VP9 encoder is primarily
#     column-based.
#  “Allows use of up to 2× thread as tile columns.” ― 2017 docs
#  “Currently, the improved MT encoder works in 1-pass/2-pass good quality
#     mode encoding at speed 0, 1, 2, 3 and 4.”
#  ― https://groups.google.com/a/webmproject.org/forum/#!topic/codec-devel/oiHjgEdii2U
#  Enabling row-mt improves encoding speed from 1/6 up to 2 times, and produces
#  video with a better perceptible quality and an equal SSIM score up to thou-
#  sands. See “Tests. VP9: row-mt on and off” in the wiki for more details.
#
libvpx_vp9_row_mt=1


 # Token parts (slices)
#  -tile-columns predecessor in VP8. Has no function in VP9.
#  vpxenc-1.7.0 --help, 2016 docs and WebM SDK explicitly omit support in VP9.
#  Topic in Google groups has a hint: “you can substitute --tile-columns
#     for --token-parts for VP9.”
#  ― https://groups.google.com/a/webmproject.org/d/msg/webm-discuss/ARlIuScFQFQ/j4xnhEpJCAAJ
#  Nadeshiko doesn’t use it.
#
#libvpx_vp9_token_parts


 # Place for user-specified output ffmpeg options
#  These options are added to the end of the encoding line after the the
#  common output options, but before the mandatory ones. So the options
#  specified here can override most of the output parameters, except those,
#  that control -pass 1, -pass 2, -sn, and the output file name. Mandatory
#  options are defined in the particular encoding module. Normally there’s
#  nothing that needs to be added. These arrays simply provide a possibility
#  to add custom ffmpeg options for specific cases (if you need extra filters,
#  mapping, control of the container format, metadata – such things).
#  Array of strings!  e.g. =(-key value  -other-key "value with spaces")
#
libvpx_vp9_pass1_extra_options=()
libvpx_vp9_pass2_extra_options=()



                     #  Unsafe libvpx-vp9 options  #

 # Manual quantiser control (use at your own risk!)
#  !
#  !  To get predictable bit rate and file size, Nadeshiko uses only values
#  !    in “libvpx-vp9_min_q” and “libvpx-vp9_max_q” variables from the
#  !    resolution profiles above (bitres_profile_NNNp). Uncommenting
#  !    “libvpx_vp9_cq_level”, “libvpx_vp9_min_q” or “libvpx_vp9_max_q”
#  !    turns on manual control over the quantiser; min_q and max_q from
#  !    the resolution profiles will be ignored.
#  !  Precise file size and bitrate are not guaranteed. Issues caused
#  !    by the usage of manual control will be closed as WONTFIX.
#  !  Manual quantiser control is for the people who have read Nadeshiko wiki,
#  !    understand what they’re doing this for and know, what they will get.
#  !
#  Quantiser threshold (ffmpeg -crf / vpxenc --end-usage=cq, --cq-level)
#  0–63. Default is 10.
#  Recommended values:
#  ⋅ 23 for CQ mode by webmproject.org;
#  ⋅ 15–35 in “Understanding rate control modes…”;
#  ⋅ From 31 for 1080 to 36 for 360p in the docs on Google Devs.
#
#libvpx_vp9_cq_level=23


 # Quantiser constraints
#  Because apparently, -crf without -qmax likes 63 too much w
#  These two parameters are the main levers on part with -deadline and
#    -cpu-used, tuning everything else without them is futile.
#
#libvpx_vp9_min_q=23
#libvpx_vp9_max_q=23



 # Some descriptions of libvpx-vp9 options are quoted from
#  https://sites.google.com/a/webmproject.org/wiki/ffmpeg/vp9-encoding-guide
#  and https://developers.google.com/media/vp9/
#  which impose restrictions on sharing, so here are the licences:
#  - text: http://creativecommons.org/licenses/by/3.0/
#  - code samples: http://www.apache.org/licenses/LICENSE-2.0