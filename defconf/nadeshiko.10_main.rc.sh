#  nadeshiko.rc.sh
#
#  Main configuration file. Codec-specific options reside in the defconf/
#  directory
#
#  RC file uses bash syntax:
#    key=value
#  Quotes can be omitted, if the value is a string without spaces.
#  The equals sign should stick to both key and value – no spaces around “=”.
#
#  Nadeshiko wiki may answer a question before you ask it!
#  https://github.com/deterenkelt/Nadeshiko/wiki



                         #  Common options  #

 # Checking for updates
#  From time to time Nadeshiko may check for updates (40 kilobytes)
#  and display a message, if a new release would be available.
#  Default value: no
#
check_for_updates=no


 # Interval in days to check for updates
#  Doesn’t do anything, if check_for_updates is set to “no”.
#  Default value: 21
#
new_release_check_interval=21


 # Whether to send notifications to desktop.
#  Default value: yes
#
desktop_notifications=yes


 # Maximum size for encoded file
#
#  [kMG] suffixes use powers of 2, unless kilo is set to 1000.
#
#
 # Normal size. Command line option to force this maximum size: “normal”.
#  Default value: 20M
#
max_size_normal=20M
#
#
 # Small size. Command line option to force this maximum size: “small”.
#  Default value: 10M
#
max_size_small=10M
#
#
 # Tiny size. Command line option to force this maximum size: “tiny”.
#  Default value: 2M
#
max_size_tiny=2M
#
#
 # Unlimited size. For manual control and experiments. Intended to be used
#  along with vbNNNN, abNNNN and XXXp. Command line option to force this
#  maximum size: “unlimited”.
#  Default value: 99999M
#
max_size_unlimited=99999M
#
#
 # Which of the max_size_* options to use by default.
#  One of: tiny, small, normal, unlimited
#  Default value: normal
#
max_size_default=normal
#
#
 # Multiplier for “k” “M” “G” suffixes in max_size_*. Can be 1024 or 1000.
#  Change this to 1000, if the server, that you often upload to, uses SI units
#    and complains about exceeded maximum file size.
#  For a one time override pass “si” or “k=1000” via command line.
#  Default value: 1024
#
kilo=1024


 # Nadeshiko always guarantees, that encoded file fits the maximum size.
#  On top of that Nadeshiko may run additional checks. They will ensure, that
#  - the container is built exactly with the settings;
#  - the encoded file is compatible with most devices.
#  Only for libx264. Prints messages only to console.
#  Default value: off
#
pedantic=off


 # Whether to show the time spent on encoding.
#  Default value: off
#
time_stat=off


 # Save the encoded file with colons (:) and other windows-unfriendly
#  characters replaced with dots (.) in the filename. This way windows
#  programs could be able to download the file from the internet without
#  renaming it (in Windows™ a colon is an invalid character for a file name).
#  If you’re dualbooting, then enabling this option will allow to launch
#  the videos from the drive.
#  Default value: no
#
create_windows_friendly_filenames=no



                         #  FFmpeg options  #

 # Calling name for the FFmpeg binary.
#  To direct nadeshiko to a custom path, where ffmpeg is installed, specify
#  the absolute path here.
#  Default value: 'ffmpeg'
#
ffmpeg='ffmpeg'
#
#
 # Input file options for encoding.
#  Extend this array with strings, one option or key per string.
#  Example: ffmpeg_input-options=(
#               -some_key  argument
#               -some_other_key "argument with spaces"
#           )
#  Default value: an empty array
#
ffmpeg_input_options=()
#
#
 # Input colourspace options
#  FFmpeg usually sets it appropriately, so the only time, when it might need
#    to be set by hand is when it for some reason cannot. Mind, that some
#    codecs (libvpx-vp9, I am looking at you) may change some of the colours
#    at will, and this isn’t related to colourspace conversion, this is just
#    how the codec works.
#  That FFmpeg chooses colourspace automatically doesn’t mean you will see
#    that in the log of pass1 or pass2, this goes in the internal kitchen,
#    where it converts ffmpeg parameters into codec parameters and adds some
#    defaults. You don’t see any --cq-level or --speed there, right?
#  Not all standards require the same setting for each of the three parameters.
#  Nadeshiko does not apply colorspace filter to the output, so in the output
#    the colorspace is defined by the codec default setting (libvpx-vp9
#    defaults to BT.709, libx264 should too).
#  Colourspace conversion is lossy, so it shouldn’t be enabled
#    without a necessity.
#
#ffmpeg_color_primaries='bt709'
#ffmpeg_color_trc='bt709'
#ffmpeg_colorspace='bt709'


 # Video codec
#  “libx264” – good quality, fast, options are well-known.
#  “libvpx-vp9” – better picture quality, better efficiency in frames per MiB,
#                 but slower and its behaviour is less predictable.
#  Default value: 'libvpx-vp9'
#
ffmpeg_vcodec='libvpx-vp9'


 # Audio codec
#        Name  Compatible  Notes
#               container
#     libopus     WebM     The best.
#   libvorbis     WebM     Quite good.
#  libfdk_aac      MP4     Equally good as Vorbis, the best FFmpeg has for MP4.
#                            The licence doesn’t allow to build distributable
#                            packages with this library, so you’ll have to com-
#                            pile FFmpeg yourself in order to have libfdk_aac.
#         aac      MP4     Still good, but worse than libvorbis and worse than
#                          libfdk_aac on bitrates <128k.
#  libmp3lame      MP4     Less efficient than all abovementioned.
#  Default value: 'libopus'
#
ffmpeg_acodec='libopus'


 # Container
#  “mp4” – use for libx264.
#  “webm” – use for libvpx-vp9.
#  “auto” – pick appropriate container based on the chosen set of A/V codecs.
#  Default value: auto
#
container=auto


 # Default action for hardcoding subtitles
#  “yes” – hardcode (burn subtitles into video frames)
#  “no” – do not add any type of subtitles.
#  Default value: yes
#
subs=yes


 # Default action for re-encoding audio track and adding it to the clip
#  “yes” – add an audio track
#  “no” – do not add any audio tracks
#  Default value: yes
#
audio=yes


 # Subtitle font and style to use, when they are not defined,
#    e.g. when rendering SubRip or VTT subtitles, which have no embedded style.
#    Mpv uses its own options for rendering those, but unfortunately, trans-
#    lating mpv options makes little sense in this case – rendering techniques
#    differ and give different result.
#  The items of this array are fed to FFmpeg’s subtitle filter as force_style
#    parameter. force_style uses SSA style fields, see chapter 5. Style lines
#    in this doc: http://moodub.free.fr/video/ass-specs.doc
#
ffmpeg_subtitle_fallback_style=(

	#  Font family name.
	#  Format: any string, escaping is not needed.
	[Fontname]='Roboto Medium'

	#  Font size
	[Fontsize]='24'

	#  Text colour
	#  Format: &HCC332211, hex codes in ABGR order, prepended with “&H”.
	#  Alpha: 00 = non-transparent, FF = transparent.
	[PrimaryColour]='&H00F0F0F0'

	#  Uncertain. “may be used instead of the Primary colour” (how?!)
	#  Format: see PrimaryColour
	#[SecondaryColour]=''

	#  Text outline colour. Description warns, that it “may be used instead
	#  of the Primary or Secondary colour”
	#  Format: see PrimaryColour
	[OutlineColour]='&H03111111'

	#  Uncertain. The description says: “the colour of the subtitle outline
	#  or shadow, if these are used.”
	#  Format: see PrimaryColour
	#[BackColour]=''
	#
	# ^ Note the British spelling – it is a standard here.

	#  Format: -1 = True, 0 = False
	#[Bold]=''

	#  Format: 1 = Outline + drop shadow, 3 = Opaque box
	[BorderStyle]='1'

	#  If BorderStyle is 1, then this specifies the width of the outline
	#  around the text, in some abstract measure.
	#  Format: 0, 1, 2, 3 or 4.
	[Outline]='2'

	#  If BorderStyle is 1, then this specifies the depth of the drop shadow
	#  behind the text, in some abstract measure too, probably. Drop shadow
	#  is always used in addition to an outline – SSA will force an outline
	#  of 1 pixel if no outline width is given.
	#  Format: 0, 1, 2, 3 or 4.
	[Shadow]='0'
)


 # Default scaling
#  Enable, if you want encoded videos to be not larger than the specified
#    resolution. This option enables a kind of “auto-scale” and differs from
#    the command line option “scale” by that it doesn’t force (fixate) the
#    resolution – Nadeshiko will be able to choose a smaller profile, if it
#    will be necessary to fit the duration.
#  Possible values are 2160p, 1440p, 1080p, 720p, 576p, 480p, 360p and “no”.
#  Default value: no
#
scale=no


 # Threshold of the seconds-per-scene ratio between static and dynamic videos
#  Before the encode, clips are analysed for this ratio. If the ratio would be
#    lower, than specified here, the clip will be considered dynamic, if the
#    ratio happens to be equal or higher – the clip will count as statc.
#  Dynamic clips lock bitrate-resolution range on desired values –
#    high motion calls for the top bitrate possible.
#  Default value: 2.5
#
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
#
crop_uses_profile_vbitrate=yes


 # Minimum ESP unit is used in overshoot prevention algorithm, where it char-
#    acterises the minimum space on which the appendage to the muxing overhead
#    should increase on re-encoding.
#  It isn’t currently bound to the ESP unit calculated at real time in any way
#    and represents the minimal step in space change, that is sensible, there-
#    fore the “absolute minimum” is a space required by the minimal bitrate
#    in the lowermost bitrate-resolution profile (currently this is 60% of
#    276k @360p for VP9, which is equivalent to 166k)
#  Default value: "166k"
#
min_esp_unit=166k


#  This user’s config file may be further extended with options. Each codec
#  and container have their specific configuration files – they reside in the
#  “defconf” directory, which can be found either in the root of the stand-
#  alone installation (repository), or, if Nadeshiko was installed as a pack-
#  age, within /usr/share/nadeshiko or /usr/local/share/nadeshiko.