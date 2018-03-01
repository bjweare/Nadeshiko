# nadeshiko.sh rc file.

 # Default values. Edit nadeshiko.rc.sh to override them.
#
# Output container.
container=mp4
#
# Output size. kMG suffixes use powers of 2, unless $kilo is set to 1000.
max_size=20M
#
# Video bitrate, in kbit/s.
# In “dumb” mode serves as a lower border, beyond which Nadeshiko
# will refuse to encode.
vbitrate=1500k
#
# Audio bitrate, in kbit/s. CBR.
abitrate=98k
#
#  Multiplier for max_size “k” “M” “G” suffixes. Can be 1024 or 1000.
#  Reducing this value may solve problem with videos not uploading
#  because file size limit uses powers of 10 (10, 100, 1000…)
kilo=1024
#
# Space in bits required for container metadata.
# Currently set to 0, because ffmpeg fits everything nicely to $max_size.
container_own_size=0
#
# “small” command line parameter to override max_size
video_size_small=10M
# “tiny” command line parameter to override max_size
video_size_tiny=2M


 # Encoder options.
#
#   FFmpeg binary.
ffmpeg='ffmpeg -hide_banner -v error'
#
#   Chroma subsampling.
#   Browsers do not support yuv444p yet.
ffmpeg_pix_fmt='yuv420p'
#
#  Video codec.
#  Browsers do not support libx265 yet.
ffmpeg_vcodec='libx264'
#
#  Video codec preset.
#  Anything slower would be placebo.
ffmpeg_preset='ultrafast'
#
#   Video codec preset tune.
#   “film” or “animation”. “medium” and lower make visible artifacts.
ffmpeg_tune='film'
#
#   Video codec profile.
#   Browsers do not support high10 or high444p
ffmpeg_profile='high'
#
#   Video codec profile level.
#   Higher profiles optimise bitrate better.
ffmpeg_level='6.2'
#
#   Audio codec.
#   If you don’t have libfdk_aac, use either “libvorbis” or “aac″.
ffmpeg_acodec='libfdk_aac'


 # The following lines describe bitrate-resolution profiles.
#  Desired bitrate is the one we aim to have, and the minimal is the lowest
#  on which we agree.
#
#  To find the balance between resolution and quality,
#  nadeshiko.sh offers three modes:
#  - dumb mode: use default values of max_size and abitrate, ignore vbitrate
#    and fit as much video bitrate as max_size allows.
#  - intellectual mode: operates on desired and minimal bitrate – see below.
#  - forced mode: apply bitrates passed through the command line:
#    ( <vbNNNNsuffix> <abNNNNsuffix>, e.g. vb2M, vb1700k, ab192k).
#    forced > intellectual > dumb
#
#  About appropriate bitrate for different resolutions, read
#  http://www.lighterra.com/papers/videoencodingh264/
#  https://teradek.com/blogs/articles/what-is-the-optimal-bitrate-for-your-resolution
#
video_360p_desired_bitrate=500k
video_360p_minimal_bitrate=220k
audio_360p_bitrate=98k
#
video_480p_desired_bitrate=1000k
video_480p_minimal_bitrate=400k
audio_480p_bitrate=128k
#
video_576p_desired_bitrate=1500k
video_576p_minimal_bitrate=720k
audio_576p_bitrate=128k
#
video_720p_desired_bitrate=2000k
video_720p_minimal_bitrate=800k
audio_720p_bitrate=128k
#
video_1080p_desired_bitrate=3500k
video_1080p_minimal_bitrate=1500k
audio_1080p_bitrate=128k
#
 # Preserve more quality at the cost of lowering resolution.
#  If set and calculations for the original (or requested) resolution show,
#  that the video encoded with desired bitrate corresponding to that
#  resolution, won’t fit in the requested max_size, then redo calculations
#  for a lower resolution. The first from the lower ones, that will allow
#  to have a desired bitrate (by default lower resolutions have lower
#  requirements for desired and minimal bitrates), will be chosen and
#  the video will be scaled down to avoid artifacts.
#
#  Values:
#    “desired” – pick resolution that would allow its desired bitrate.
#    “minimal” – pick resolution that would allow its minimal bitrate.
#    commented (i.e. unset) – do not enable intellectual mode.
#

