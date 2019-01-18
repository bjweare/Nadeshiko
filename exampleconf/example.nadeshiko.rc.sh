#  nadeshiko.rc.sh v2.3.13


#  RC file uses bash syntax:
#    key=value
#  Quotes can be omitted, unless the string with value has spaces.
#  The equals sign should stick to both key and value. No spaces around “=”.
#
#  Nadeshiko wiki may answer a question before you ask it!
#  https://github.com/deterenkelt/Nadeshiko/wiki




                         #  Common options  #

 # Checking for updates
#  From time to time Nadeshiko will check for updates (40 kilobytes)
#  and display a message, if a new release would be available.
#  Default value: yes
check_for_updates=yes
#
#  Interval in days to check for updates
#  Doesn’t do anything, if check_for_updates is set to “no”.
#  Default value: 21
new_release_check_interval=21


 # Whether to send notifications to desktop.
#  Default value: yes
desktop_notifications=yes


 # Maximum size for encoded file
#
#  [kMG] suffixes use powers of 2, unless kilo is set to 1000.
#
#  Normal size. Command line option to force this maximum size: “normal”.
#  Default value: 20M
max_size_normal=20M
#
#  Small size. Command line option to force this maximum size: “small”.
#  Default value: 10M
max_size_small=10M
#
#  Tiny size. Command line option to force this maximum size: “tiny”.
#  Default value: 2M
max_size_tiny=2M
#
#  Unlimited size. For manual control and experiments. Intended to be used
#  along with vbNNNN, abNNNN and XXXp. Command line option to force this
#  maximum size: “unlimited”.
#  Default value: 99999M
max_size_unlimited=99999M
#
#  One of: tiny, small, normal, unlimited
#  Default value: normal
max_size_default=normal
#
#
#  Multiplier for max_size “k” “M” “G” suffixes. Can be 1024 or 1000.
#  For a one time override pass “si” or “k=1000” via command line.
#    Change this to 1000, if the server you often upload to uses SI units
#    and complains about exceeded maximum file size.
#  Default value: 1024
kilo=1024


 # Nadeshiko always guarantees, that encoded file fits the maximum size.
#  On top of that Nadeshiko may run additional checks. They will ensure, that
#  - the container is built exactly with the settings;
#  - the encoded file is compatible with most devices.
#  Only for libx264. Prints messages only to console.
#  Default value: no
pedantic=no


 # Whether to show the time spent on encoding.
#  Default value: no
time_stat=no


 # Save the encoded file with colons (:) and other windows-unfriendly
#  characters replaced with dots (.) in the filename. This way windows
#  programs could be able to download the file from the internet without
#  renaming it (in Windows™ a colon is an invalid character for a file name).
#  If you’re dualbooting, then enabling this option will allow to launch
#  the videos from the drive.
#  Default value: no
create_windows_friendly_filenames=no



                         #  FFmpeg options  #

 # FFmpeg binary
#  Default value: 'ffmpeg -v error -nostdin'
ffmpeg='ffmpeg -v error -nostdin'
#
#  Chroma subsampling
#  Not all browsers support yuv422 or yuv444p yet.
#  VP9 encodes well with yuv444p! Plays in the old FF-52 ESR.
#  Default value: 'yuv420p'
ffmpeg_pix_fmt='yuv420p'
#
#  Colourspace options
#  Convert source video colourspace to the given standard.
#  By default ffmpeg uses native source colourspace, but browsers may not
#    recognise some of them properly. In this case try to enable these options.
#  Not all standards require the same setting for each of the three parameters.
#  Setting them adds colourspace metadata, without which some dumb players
#    (hardware, flash/silverlight/java…) cannot play the video properly.
#  Colourspace conversion is lossy, so it shouldn’t be enabled
#    without a necessity.
#ffmpeg_color_primaries='bt709'
#ffmpeg_color_trc='bt709'
#ffmpeg_colorspace='bt709'


 # A/V codecs and containers
#  Supported combinations:
#  1) libx264 + libfdk_aac/aac in mp4
#  2) libvpx-vp9 + libopus/libvorbis in webm (Nadeshiko’s default since v1.2)
#
#  Video codec
#  “libx264” – good quality, fast, options are well-known.
#  “libvpx-vp9” – better picture quality, better efficiency in frames per MiB,
#                 but slower and its behaviour is less predictable.
#  Default value: 'libvpx-vp9'
ffmpeg_vcodec='libvpx-vp9'
#
#  Audio codec
#  “libopus” – the best out there, but only for webm, hence libvpx-vp9.
#  “libvorbis” – good, but only for webm, hence libvpx-vp9.
#                May produce unexplainably large audio tracks in webm,
#                so better don’t use it, if you can use Opus.
#  “libfdk_aac” – equally good as Vorbis, for mp4, hence libx264.
#                 The best out there for MP4. The licence doesn’t allow
#                 to build distributable packages with this library, so you’ll
#                 have to compile FFmpeg yourself in order to have libfdk_aac.
#  “aac” – still good, but worse than libvorbis and libfdk_aac.
#  “libmp3lame”, “ac3”… – it’s 2018, don’t use them.
#  Default value: 'libopus'
ffmpeg_acodec='libopus'
#
#  Container
#  “mp4” – use for libx264.
#  “webm” – use for libvpx-vp9. Needs libvpx-1.7+ installed.
#  “auto” – pick appropriate container based on the chosen set of A/V codecs.
#  Default value: auto
container=auto
#
#  Space required for the container header and footer.
#  The value is a percent of the maximum allowed file size, e.g. “1%”, “5%”.
#  Default value: 3%
container_own_size_pct=3%


 # The defaults for hardcoding subtitles into video and adding audio track.
#  Default is “yes” for both.
subs=yes
audio=yes


 # Subtitle font and style to use, when they are not defined,
#    e.g. when rendering SubRip or VTT subtitles, which have no embedded style.
#    Mpv uses its own options for rendering those, but unfortunately, trans-
#    lating mpv options makes little sense in this case – rendering techniques
#    differ and give different result.
#  The items of this array are fed to FFmpeg’s subtitle filter as force_style
#    parameter. force_style uses SSA style fields, see chapter 5. Style lines
#    in this doc: with http://moodub.free.fr/video/ass-specs.doc
#  Recommended set: Fontname='Roboto Medium', Fontsize=21,
#    PrimaryColour=&H00F0F0F0, Borderstyle=1 Outline=1 Shadow=0.
#  By default this array of options is set, but empty, and doesn’t affect
#    anything.
ffmpeg_subtitle_fallback_style=(

	#  Font family name.
	#  Format: any string, escaping is not needed.
	#[Fontname]='Roboto Medium'

	#  Font size
	#[Fontsize]='24'

	#  Text colour
	#  Format: &HCC332211, hex codes in ABGR order, prepended with “&H”.
	#  Alpha means transparency: 00 = 0%, FF = 100%.
	#[PrimaryColour]='&H00F0F0F0'

	#  Uncertain. “may be used instead of the Primary colour” (how?!)
	#  Format: see PrimaryColour
	#[SecondaryColour]=''

	#  Text outline colour. Description warns, that it “may be used instead
	#  of the Primary or Secondary colour”
	#  Format: see PrimaryColour
	#[OutlineColour]='&H03111111'

	#  Uncertain. The description says: “the colour of the subtitle outline
	#  or shadow, if these are used.”
	#  Format: see PrimaryColour
	#[BackColour]=''
	#
	# ^ Note the British spelling – it is a standard here.

	#  Format: -1 = True, 0 = False
	#[Bold]=''

	#  Format: 1 = Outline + drop shadow, 3 = Opaque box
	#[BorderStyle]='1'

	#  If BorderStyle is 1, then this specifies the width of the outline
	#  around the text, in some abstract measure.
	#  Format: 0, 1, 2, 3 or 4.
	#[Outline]='2'

	#  If BorderStyle is 1, then this specifies the depth of the drop shadow
	#  behind the text, in some abstract measure too, probably. Drop shadow
	#  is always used in addition to an outline – SSA will force an outline
	#  of 1 pixel if no outline width is given.
	#  Format: 0, 1, 2, 3 or 4.
	#[Shadow]='0'
)


 # Default scaling
#  Enable, if you want encoded videos to be not larger than the specified
#    resolution. This option enables a kind of “auto-scale” and differs from
#    the command line option “scale” by that it doesn’t force (fixate) the
#    resolution – Nadeshiko will be able to choose a smaller profile, if it
#    will be necessary to fit the duration.
#  Possible values are 2160p, 1440p, 1080p, 720p, 576p, 480p, 360p and “no”.
#  Default value: no
scale=no


 # Threshold of the seconds-per-scene ratio between static and dynamic videos
#  Before the encode, clips are analysed for this ratio. If the ratio would be
#    lower, than specified here, the clip will be considered dynamic, if the
#    ratio happens to be equal or higher – the clip will count as statc.
#  Dynamic clips lock bitrate-resolution range on desired values –
#    high motion calls for the top bitrate possible.
#  Default value: 2.5
video_sps_threshold=2.5


 # Whether cropped videos should use bitrate specified in the profile
#    chosen for the source file. Normally the bitrate would be recalculated
#    in the proportion of crop area to frame area. However, that *may be* –
#    not always – insufficient, because what you crop will probably have
#    a good part of the motion in a frame, thus the major part of the bitrate
#    would be spent on this exact cropped part, if the entire frame would be
#    encoded. This is probably why the demand for bitrate of the cropped
#    part draws close to the demand of the entire frame.
#  Default value: yes
crop_uses_profile_vbitrate=yes




                    #  Options for advanced users   #

 # Bitrate-resolution profiles
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
#  The lower border when seeking for the TARGET video bitrate.
#  Calculated as a percentage of the desired bitrate. Highly depends
#    on CPU time, that encoder spends. If you speed up the encoding
#    by putting laxed values in libx264_preset or libvpx_pass*_cpu_used,
#    you should rise the percentage here.
#  Don’t confuse with libvpx_minrate and libvpx_maxrate.
#  Default value: 60%
minimal_bitrate_pct=60%
#
#  Read on the wiki
#  - what profiles do: https://git.io/fxJhR
#  - how profiles work: https://git.io/fxJpu
bitres_profile_360p=(
	[libx264_desired_bitrate]=500k
	[libvpx-vp9_desired_bitrate]=276k
	# [libvpx-vp9_min_q]=35
	[libvpx-vp9_max_q]=40
	[audio_desired_bitrate]=98k
)

bitres_profile_480p=(
	[libx264_desired_bitrate]=1000k
	[libvpx-vp9_desired_bitrate]=750k
	# [libvpx-vp9_min_q]=33
	[libvpx-vp9_max_q]=39
	[audio_desired_bitrate]=98k
)

bitres_profile_576p=(
	[libx264_desired_bitrate]=1500k
	[libvpx-vp9_desired_bitrate]=888k
	# [libvpx-vp9_min_q]=33
	[libvpx-vp9_max_q]=38
	[audio_desired_bitrate]=98k
)

bitres_profile_720p=(
	[libx264_desired_bitrate]=2000k
	[libvpx-vp9_desired_bitrate]=1024k
	# [libvpx-vp9_min_q]=32
	[libvpx-vp9_max_q]=37
	[audio_desired_bitrate]=112k
)

bitres_profile_1080p=(
	[libx264_desired_bitrate]=3500k
	[libvpx-vp9_desired_bitrate]=1800k
	# [libvpx-vp9_min_q]=31
	[libvpx-vp9_max_q]=36
	[audio_desired_bitrate]=128k
)

# Experimental.
bitres_profile_1440p=(
	[libx264_desired_bitrate]=11900k
	[libvpx-vp9_desired_bitrate]=6000k
	# [libvpx-vp9_min_q]=24
	[libvpx-vp9_max_q]=34
	[audio_desired_bitrate]=128k
)

# Experimental.
bitres_profile_2160p=(
	[libx264_desired_bitrate]=23900k
	[libvpx-vp9_desired_bitrate]=12000k
	# [libvpx-vp9_min_q]=15
	[libvpx-vp9_max_q]=25
	[audio_desired_bitrate]=128k
)



                         #  libx264 options  #

 # Speed / quality preset
#  “veryslow” > “slower” > “slow” > shit > “medium” > … > “ultrafast”.
libx264_preset='veryslow'
#
#  Preset tune. Less significant than the preset itself
#  “animation” / “film” > shit > “fastdecode” > “zerolatency”.
#  “animation” = “film” + more B-frames.
libx264_tune='animation'
#
#  Profile enables encoding features. A decoder must also support them
#  in order to play the video
#  high444p > high10 > high > main > baseline
#  Browsers do not support high10 or high444p.
libx264_profile='high'
#
#  Video codec profile level
#  Higher profiles optimise bitrate better.
#  Very old devices may require level 3.0 and baseline profile.
libx264_level='4.2'
#
#  Keyframe interval
libx264_keyint=50
#
#  Place for user-specified ffmpeg options
#  These will be applied ONLY when used with libx264 as an encoder.
#  Array of strings!  I.e. =(-key value  -other-key "value with spaces")
libx264_pass1_extra_options=()
libx264_pass2_extra_options=()




                        #  libvpx-vp9 options  #

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
libvpx_tile_columns=6
#
#  Same as tile-columns, but for rows.
#  Usefulness is uncertain, as vpxenc hints, that it’s set to 0 when threads
#  is used: “Number of tile rows to use, log2 (set to 0 while threads > 1)”.
#libvpx_tile_rows
#
#  Maximum number of CPU threads to use.
#  The docs on Google Devs recommend to calculate it, so whether the value
#  here will in effect or not, depends on whether libvpx_adaptive_tile_columns
#  is enabled (see below).
libvpx_threads=8
#
#  When enabled, Nadeshiko calculates the values for tile-columns and threads
#  adaptively to the video resolution as the docs on Google Devs recommend:
#  tile-columns = log2(target video width / tile-column minimum width)
#  threads = 2^tile-columns × 2
libvpx_adaptive_tile_columns=yes
#
#  Frame parallel decodability features
#  “Turns off backward update of probability context”, which supposedly should
#  mean, that B-frames would be based only on their predecessors. This option
#  “allows staged parallel processing of more than one video frames
#  in the decoder”. Spotted to hurt quality in the tests.
#  0 – disable
#  1 – enable
libvpx_frame_parallel=0
#
#  Encode speed / quality profiles
#  --deadline ffmpeg option specifies a profile to libvpx. Profiles are
#    “best” – a kind of “placebo” in libvpx, although not as pointless.
#    “good” – around “slow”, “slower” and “veryslow”, the range we need.
#    “realtime” – fast encoding for streaming, poor quality as always.
#        “Setting --good and --cpu-used=0 will give quality that is usually
#         very close to and even sometimes better than that obtained with
#         --best, but the encoder will typically run about twice as fast.”
#  --cpu-used is tweaking the profiles above. 0, 1 and 2 give best results
#    with “best” and “good” profiles. “Values greater than 0 will increase
#    encoder speed at the expense of quality. Changes in this value influen-
#    ces, among others, the encoder’s selection of motion estimation methods.”
#    This is actually of CRITICAL importance to get better quality.
#    −8…8 are the values for VP9 (−16…16 was allowed for VP8).
libvpx_pass1_deadline=good
libvpx_pass1_cpu_used=4
libvpx_pass2_deadline=good
libvpx_pass2_cpu_used=0
#
#  Frame prefetch for the buffer
#  “Setting auto-alt-ref and lag-in-frames >= 12 will turn on VP9’s alt-ref
#   frames, a VP9 feature that enhances quality.”
#  “When --auto-alt-ref is enabled, the default mode of operation is to either
#   populate the buffer with a copy of the previous golden frame, when this
#   frame is updated, or with a copy of a frame derived from some point
#   of time in the future.”
#  “Use of --auto-alt-ref can substantially improve quality in many
#   situations (though there are still a few where it may hurt).” > 2016
#  0 – disabled (default).
#  1 – enabled.
libvpx_auto_alt_ref=1
#
#  Upper limit on the number of frames into the future,
#  that the encoder can look for --auto-alt-ref.
#  0–25. 25 is the default. 16 is recommended by webmproject.org.
libvpx_lag_in_frames=25
#
#  Maximum interval between key frames (ffmpeg -g).
#  “It is recommended to allow up to 240 frames of video between keyframes…”
#  240 is the default.
#  99999 is recommended by webmproject.org, so you couldn’t have keyframes.
#  ― Ah, so that’s why webms take less space… Humu humu.
libvpx_kf_max_dist=9999
#
#  Isn’t implemented in libvpx-vp9.
#libvpx_kf_min_dist
#
#  Lower and upper bitrate borders for a GOP, in % from target bitrate.
#  50% and 145% are recommended by the docs on Google Devs.
libvpx_minsection_pct=50
libvpx_maxsection_pct=145
#
#  Datarate overshoot (maximum) target (%)
#  How much deviation in size from the target bitrate is allowed.
#  −1…1000, default is −1.
libvpx_overshoot_pct=0
#
#  Datarate undershoot (minimum) target (%)
#  How much deviation in size from the target bitrate is allowed.
#  −1…100, default is −1.
libvpx_undershoot_pct=0
#
#  CBR/VBR bias (0=CBR, 100=VBR)
#  Default is unknown. Nadeshiko doesn’t use it by default (but may apply).
#libvpx_bias_pct=0
#
#  Adaptive quantisation mode
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
libvpx_aq_mode=0
#
#  Maximum keyframe bitrate as a percentage of the target bitrate
#  This value controls additional clamping on the maximum size of a keyframe.
#  It is expressed as a percentage of the average per-frame(!) bitrate, with
#  the special (and default) value 0 meaning unlimited, or no additional
#  clamping beyond the codec's built-in algorithm.
#  Nadeshiko currently doesn’t use it.
#libvpx_max_intra_rate
#
#  Maximum I-frame bitrate as a percentage of the target bitrate
#  This value controls additional clamping on the maximum size of an inter
#  frame. It is expressed as a percentage of the average per-frame bitrate,
#  with the special (and default) value 0 meaning unlimited, or no additional
#  clamping beyond the codec’s built-in algorithm.
#  Nadeshiko currently doesn’t use it; even ffmpeg-san has no option for it w
#libvpx_max_inter_rate
#
#  Source video type
#  0: default – for any video
#  1: screen – screen capture
#  2: film – to preserve film grain(? no official description.)
#  Nadeshiko doesn’t use it.
#libvpx_tune_content
#
#  Static threshold
#  Should be understood literally: it’s an option to suppress noise on live
#  translations, where real movements are low. Causes regions on image not
#  being updated, which leads to artefacts. If you looked for motion-estima-
#  tion methods, it’s defined by --cpu-used in VP9.
#  “In most scenarios this value should be set to 0.”
#  Nadeshiko doesn’t use this.
#libvpx_static_threshold
#
#  Strip encoding features to ease playback
#  Used for low-capable devices or for enormous bitrates of 4K and higher.
#  “For non-zero values the encoder increasingly optimizes for reduced comp-
#   lexity playback on low powered devices at the expense of encode quality.”
#  https://www.webmproject.org/docs/encoder-parameters/
#  Nadeshiko doesn’t use this option.
#libvpx_profile
#
#  vpxenc --target-level
#  Should be similar to the levels for libx264 (see above).
#  https://www.webmproject.org/vp9/levels/
libvpx_level=4.2
#
#  Literally an optimisation to pass synthetic tests better.
#  SSIM is considered closer to the human eye perception.
#  “psnr” (default)
#  “ssim” (isn’t supported for VP9 in libvpx-1.7.0)
#  > Failed to set VP8E_SET_TUNING codec control: Invalid parameter
#  > Option --tune=ssim is not currently supported.
#libvpx_tune=ssim
#
#  Row based multi-threading.
#  0 = off, 1 = on.
#  -> non-deterministic: two encodes will not be the same.
#  -> “rows” refers to the rows of macroblocks within a single tile-column.
#     It doesn’t refer to -tile-rows, VP9 encoder is primarily column-based.
#  -> “Allows use of up to 2x thread as tile columns.” ― 2017 docs
#  “Currently, the improved MT encoder works in 1-pass/2-pass good quality
#   mode encoding at speed 0, 1, 2, 3 and 4.”
#  ― https://groups.google.com/a/webmproject.org/forum/#!topic/codec-devel/oiHjgEdii2U
#  Enabling improves encoding speed ≈1/6…2 times, and produces video
#  with a better perceptible quality with an equal SSIM score up to thou-
#  sands. See “Tests. VP9: row-mt on and off” in the wiki for more details.
libvpx_row_mt=1
#
#  Token parts (slices)
#  -tile-columns predecessor in VP8. Has no function in VP9.
#  vpxenc-1.7.0 --help, 2016 docs and WebM SDK explicitly omit support in VP9.
#  Topic in Google groups has a hint: “you can substitute --tile-columns
#     for --token-parts for VP9.”
#  ― https://groups.google.com/a/webmproject.org/d/msg/webm-discuss/ARlIuScFQFQ/j4xnhEpJCAAJ
#  Nadeshiko doesn’t use it.
#libvpx_token_parts
#
#  Place for user-specified ffmpeg options
#  These will be applied ONLY when libvpx is used as an encoder.
#  Array of strings!  I.e. =(-key value  -other-key "value with spaces")
libvpx_pass1_extra_options=()
libvpx_pass2_extra_options=()




                     #  Unsafe libvpx-vp9 options  #

 # Manual quantiser control (use at your own risk!)
#  !
#  !  To get predictable bit rate and file size, Nadeshiko uses only values
#  !    in “libvpx-vp9_min_q” and “libvpx-vp9_max_q” variables from the
#  !    resolution profiles above (bitres_profile_NNNp). Uncommenting
#  !    “libvpx_cq_level”, “libvpx_min_q” or “libvpx_max_q” turns on manual
#  !    control over the quantiser; min_q and max_q from the resolution
#  !    profiles will be ignored.
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
#libvpx_cq_level=23
#
#  Quantiser constraints
#  Because apparently, -crf without -qmax likes 63 too much w
#  These two parameters are the main levers on part with -deadline and
#    -cpu-used, tuning everything else without them is futile.
#libvpx_min_q=23
#libvpx_max_q=23




                       #  Only for developers  #


 # Correspondences between ffmpeg codec names and the stream formats, that
#    they produce, e.g. libx264 – AVC, libvpx-vp9 – VP9.
#  This array is useful only for those developers, who write their own
#    encoding modules for Nadeshiko.
#  Knowing these pairs helps Nadeshiko to determine the similarity between
#    the original and the new encoder. This knowledge is helpful, when the
#    source bitrate is even lower, than the restrictive bitrates in Nadeshiko
#    profiles, so Nadeshiko drops the desired bitrate down to the source bit-
#    rate and saves encoding time, disk space.
#  One thing is wasting space on a high quality source (where the bitrate is
#    HIGHER than to what we encode – assuming the format is the same), then
#    throwing some spare bitrate would raise the quality of the cut video.
#    Another matter is when the source has a lower quality
#    and a LOWER bitrate – wasting space on it is futile.
#  Type: associative array.
#  Item format: [ffmpeg-codec-name]="Format as reported by mediainfo".
#
codec_names_as_formats=(
	[libx264]=AVC
	[libvpx-vp9]=VP9
)

 # Working combinations of containers and audio/video codecs.
#  One string represents a working combination. When $container is set
#    to “auto”, and the same vcodec and acodec support two containers,
#    the last entry, that would match vcodec and acodec, will be chosen.
#  Type: regular array.
#  Item format: 'container  video_codec  audio_codec'
#
can_be_used_together=(
	'mp4 libx264 libfdk_aac'
	'mp4 libx264 aac'
	'mp4 libx264 libmp3lame'
	#'mp4 libx264 libopus'  # libopus in mp4 is still experimental
	'webm libvpx-vp9 libopus'
	'webm libvpx-vp9 libvorbis'
	#  No mkv, because browsers download it instead of playing.
)

 # This list is used, when Nadeshiko needs to render subtitles, and the
#  source subtitles are a stream, that is built in the source video file.
#
known_sub_codecs=(
	ass ssa
	srt subrip webvtt vtt
	dvd_subtitle
	hdmv_pgs_subtitle
)


 # Some descriptions of libvpx-vp9 options are quoted from
#  https://sites.google.com/a/webmproject.org/wiki/ffmpeg/vp9-encoding-guide
#  and https://developers.google.com/media/vp9/
#  which impose restrictions on sharing, so here are the licences:
#  - text: http://creativecommons.org/licenses/by/3.0/
#  - code samples: http://www.apache.org/licenses/LICENSE-2.0
