# nadeshiko.rc.sh

 # Syntax
#
#  RC file uses bash syntax:
#    key=value
#  Quotes are not important, unless the string has spaces.
#  The “equal” sign should stick to key and value. Stick means
#    no spaces around.
#  Value ‘t’ means that the variable is a flag. If you need
#    to disable a flag, comment that line.
#
#  Nadeshiko wiki can answer a question before you ask it!
#  https://github.com/deterenkelt/Nadeshiko/wiki


 # Maximum size for encoded file
#
#  [kMG] suffixes use powers of 2, unless kilo is set to 1000.
max_size_default=20M
#
#  Pass “small” to the command line to use this maximum size.
max_size_small=10M
#
#  Pass “tiny” to the command line to use this maximum size.
max_size_tiny=2M
#
#  For manual control and experiments. Intended to be used
#  along with vbNNNN, abNNNN and XXXp.
max_size_unlimited=99999M
#
#  Multiplier for max_size “k” “M” “G” suffixes. Can be 1024 or 1000.
#  For a one time override pass “si” or “k=1000” via command line.
#  Change this to 1000, if the server you often upload to uses SI units
#  and complains about exceeded maximum file size.
kilo=1024


 # Precaution against broken or poorly built files. To apply a bitrate-
#  resolution profile, the resolution of the source file must be known.
#  If it cannot be determined, fallback values would be used.
#
fallback_vbitrate=1500k
fallback_abitrate=98k

 # Uncomment to disable desktop notifications.
#
# NO_DESKTOP_NOTIFICATIONS=t

 # Nadeshiko always guarantees, that encoded file fits the maximum size.
#  On top of that Nadeshiko may run additional checks. They will ensure, that
#  - the container is built exactly with the settings;
#  - the encoded file is compatible with most devices.
#  Prints messages only to console. Uncomment to enable.
#
#pedantic=t

 # Show time stats after encoding is done.
#
#time_stat=t


 # FFmpeg
#
#  FFmpeg binary.
ffmpeg='ffmpeg -v error'
#
#  Chroma subsampling.
#  Browsers do not support yuv422 or yuv444p yet.
ffmpeg_pix_fmt='yuv420p'
#
#
 # A/V codecs and containers
#  Supported combinations:
#  1) libx264 + libfdk_aac/aac in mp4 (Nadeshiko’s default)
#  2) libvpx-vp9 + libopus/libvorbis in webm (Experimental!)
#
#  Video codec
#  “libx264” – good quality, fast, options are well-known
#  “libvpx-vp9” – better quality, but slower, options are weird and quirky.
ffmpeg_vcodec='libx264'
#
#  Audio codec
#  If you don’t have libfdk_aac, use either “libvorbis” or “aac″.
#  “libopus” – best, but only for libvpx-vp9.
#  “libvorbis” – good, but only for webm, hence libvpx-vp9.
#  “libfdk_aac” – equally good, for mp4, hence libx264.
#  “aac” – still good, but worse than libvorbis and libfdk_aac.
#  “libmp3lame”, “ac3”… – it’s 2018, don’t use them.
ffmpeg_acodec='aac'
#
#
 # Container
#
#  Output container type.
#  “mp4” – use for libx264.
#  “webm” – use for libvpx-vp9. Needs libvpx-1.7+ installed.
#  “auto” – pick appropriate container based on the chosen set of A/V codecs.
container=auto
#
#  Space required for the container header and footer.
#  The value is a percent of the maximum allowed file size, e.g. “1%”, “5%”.
container_own_size=2%
#
#
 # Subtitles and audio
#  By default, burn subtitles into video and encode audio.
#  Comment to disable by default.
subs=t
audio=t
#
#
 # Default scaling
#  Sets an “upper border” for the output resolution. It doesn’t *force*
#  scale, like the NNNp command line parameters.
#  Possible values are 1080p, 720p, 576p, 480p and 360p. Disabled by default.
#scale=720p

 # Bitrate-resolution profiles
#
#  Sometimes, the new file wouldn’t fit into the maximum size – its resolu-
#    tion and/or bitrate is too big for the size. The higher the resolution
#    is, the bigger is the video bitrate it should have. It’s impossible to
#    fit 30 minutes of 1080p into 2 megabytes, for example. However, a lower
#    resolution, say, 720p, would need less bitrate, and it might fit!
#  Nadeshiko will calculate the bitrate, that would fit into the requested
#    file size, and then will try to find an appropriate resolution for it.
#    If it could be the native resolution, Nadeshiko will not scale.
#    Otherwise, to avoid an artifact-ridden say, 1080p video of poor quality,
#    Nadeshiko will make a clean one, but in a lower resolution.
#
 # For each resolution, desired and minimal video bitrates are calculated.
#  Desired is the upper border, which will be tried first, then attempts will
#  go down to the lower border, the minimal value. Steps are in 100k.
#  If the maximum fitting bitrate wasn’t in the range of the resolution,
#  the next will be tried.
#
#  The lower border for video bitrate is defined as a percentage
#  of desired bitrate.
minimal_bitrate_perc=45%
#
#  Desired bitrates are set separately for libx264 and libvpx-vp9,
#  as VP9 needs nearly twice as lower bitrates for preserving
#  the same quality.
#
libx264_360p_desired_bitrate=500k
libvpx_360p_desired_bitrate=276k
audio_360p_desired_bitrate=98k
#
libx264_480p_desired_bitrate=1000k
libvpx_480p_desired_bitrate=750k
audio_480p_desired_bitrate=98k
#
libx264_576p_desired_bitrate=1500k
libvpx_576p_desired_bitrate=888k
audio_576p_desired_bitrate=98k
#
libx264_720p_desired_bitrate=2000k
libvpx_720p_desired_bitrate=1024k
audio_720p_desired_bitrate=112k
#
libx264_1080p_desired_bitrate=3500k
libvpx_1080p_desired_bitrate=1800k
audio_1080p_desired_bitrate=128k


 # libx264 options
#
#  Speed / quality preset.
#  “veryslow” > “slower” > “slow” > shit > “medium” > … > “ultrafast”.
libx264_preset='veryslow'
#
#  Preset tune. Less significant than the preset itself.
#  “film” > “animation” > shit > “fastdecode” > “zerolatency”.
libx264_tune='film'
#
#  Profile defines set of features that decoder must have.
#  high444p > high10 > high > main > baseline
#  Browsers do not support high10 or high444p.
libx264_profile='high'
#
#  Video codec profile level.
#  Higher profiles optimise bitrate better.
#  Very old devices may require level 3.0 and baseline profile.
libx264_level='4.2'


 # libvpx-vp9 options
#
#  Quantizer threshold
#  vpxenc’s end-usage=cq, cq-level
#  0–63. Default is 10.
#  Recommended values:
#  ⋅ 23 for CQ mode by webmproject.org;
#  ⋅ 15–35 in “Understanding rate control modes…”;
#  ⋅ From 31 for 1080 to 36 for 360p on Google Devs (but lowering for 1–2
#    per resolution downgrade looks like it was just plucked out of the air).
libvpx_crf=23
#
#  Tile columns
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
#  However,
#  https://sites.google.com/a/webmproject.org/wiki/ffmpeg/vp9-encoding-guide
#  recommends -tile-columns 6 for CQ, and that means 64 tiles.
#  This actually works: ffmpeg encodes 1080p video with -tile-columns 6,
#  and in the logs there was no complain about the unfitting number of tiles
#  (256 pixels × 64 tiles must require a video 16384 pixels wide).
#  Why would they even make -tile-columns accepting 64 tiles, that supposedly
#  would only work on such enourmous videos? Something isn’t right here…
#  Must be >0 in order for threads to work.
#  6 is recommended by webmproject.org.
#  The docs on Google Devs recommend to calculate it (see below).
#  Maybe it makes sense assigning it to log2(threads).
libvpx_tile_columns=6
#
#  CPU threads to use.
libvpx_threads=4
#
#  When enabled, Nadeshiko calculates the values for tile-columns and threads
#  adaptively to the video resolution as the docs on Google Devs recommend,
#  that is 8 for 1080p and 720p, 4 for 480p and 360p and so on.
libvpx_adaptive_tile_columns=t
#
#  Frame parallel decodability features
#  Allows threads(?)
#  Must be >0 in order for threads to work.
libvpx_frame_parallel=1
#
#  Encode speed / quality profiles
#  --deadline ffmpeg option specifies a profile to libvpx. Profiles are
#    “best” – some kind of “placebo” in libvpx.
#    “good” – around “slow”, “slower” and “veryslow”, the range we need.
#    “realtime” – fast encoding for streaming, poor quality, as always.
#  --cpu-used is tweaking the profiles above. 0, 1 and 2 give best results
#    with “best” and “good” profiles. The higher the number, the worse the
#    quality gets.
#  From https://www.webmproject.org/docs/encoder-parameters/:
#  “Setting --good quality and --cpu-used=0 will give quality that is
#   usually very close to and even sometimes better than that obtained
#   with --best, but the encoder will typically run about twice as fast.”
libvpx_pass1_deadline=good
libvpx_pass1_cpu_used=4
libvpx_pass2_deadline=good
libvpx_pass2_cpu_used=1
#
#  Frame prefetch for the buffer
#  0 – disabled (default).
#  1 – enabled.
libvpx_auto_alt_ref=1
#
#  Upper limit on the number of frames into the future,
#  that the encoder can look for --auto-alt-ref.
#  0–25. 25 is the default. 16 is recommended by webmproject.org.
libvpx_lag_in_frames=16
#
#  Maximum interval between key frames
#  “It is recommended to allow up to 240 frames of video between keyframes…”
#  240 is the default.
#  9999 is recommended by webmproject.org, so you couldn’t have keyframes.
#  ― Ah, so that’s why webms take less space… Humu humu.
libvpx_keyint_max=9999
#
#  Adaptive quantization mode
#  0 – off (default)
#  1 – variance
#  2 – complexity
#  3 – cyclic refresh
#  4 – equator360
#  Never used in examples.
#libvpx_aq_mode=0
#
#  0  = 8 bit/sample, 4:2:0
#  1  = 8 bit, 4:2:2, 4:4:4
#  2  = 10 or 12 bit, 4:2:0
#  3  = 10 or 12 bit, 4:2:2, 4:4:4
#  https://www.webmproject.org/vp9/profiles/
#  …or not?
#  > For non-zero values the encoder increasingly optimizes for reduced
#    complexity playback on low powered devices at the expense of encode
#    quality.
#  https://www.webmproject.org/docs/encoder-parameters/
#  The option doesn’t exist according to the description in libvpx-vp9 codec.
#libvpx_profile=0
#
#  https://www.webmproject.org/vp9/levels/
#libvpx_level=4
#
#  Literally an optimisation to pass synthetic tests better.
#  SSIM is considered closer to the human eye perception.
#  “psnr” (default)
#  “ssim”
#  Description in libvpx-vp9 codec doesn’t exist, because libvpx…
#  doesn’t support it yet!
#  > Failed to set VP8E_SET_TUNING codec control: Invalid parameter
#  > Option --tune=ssim is not currently supported in VP9.
#libvpx_tune=ssim
#
#  Enables row-multithreading.
#  Allows use of up to 2× threads as tile columns. 0 = off, 1 = on.
#  Haven’t seen this option enabled for CQ modes, only for realtime.
#  That may mean, that is has an impact on quality.
#libvpx_row_mt=1

 # Some descriptions of libvpx-vp9 options are quoted from
#  https://sites.google.com/a/webmproject.org/wiki/ffmpeg/vp9-encoding-guide
#  and https://developers.google.com/media/vp9/
#  which impose restrictions on sharing, so here are the licences:
#  - text http://creativecommons.org/licenses/by/3.0/
#  - code samples http://www.apache.org/licenses/LICENSE-2.0