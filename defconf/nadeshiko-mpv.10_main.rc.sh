#  nadeshiko-mpv.rc.sh
#
#  Main configuration file for nadeshiko-mpv.sh. Copied as an example
#  to user’s configuration directory from defconf/.
#
#  RC file uses bash syntax:
#    key=value
#  Quotes can be omitted, if the value is a string without spaces.
#  The equals sign should stick to both key and value – no spaces around “=”.
#
#  Nadeshiko wiki may answer a question before you ask it!
#  https://github.com/deterenkelt/Nadeshiko/wiki



 # The command to launch mpv.
#
mpv='mpv'


 # Absolute path to the mpv IPC socket.
#  Before placing it here you need to confirm, that you’ve set it up
#  in the mpv’s config (usually ~/.mpv/config or ~/.config/mpv/config),
#  there should be a line like
#      input-ipc-server=/tmp/mpv-socket
#  If you call mpv from SMplayer or another wrapper, input-ipc-server
#  can be added as a command line option – but make sure you use the ‘=’ sign!
#      $ mpv --input-ipc-server=/tmp/mpv-socket
#  After assigning path to the socket for mpv, specify that path here.
#
mpv_sockets=(
	[Usual]='/tmp/mpv-socket'
)


 # Postponed encoding
#  “yes”: When encoding parameters are accepted, saves the command
#         as a job file to be run later with Nadeshiko-do-postponed.
#         Force-enables the “Encode later” checkbox in the GUI.
#  “no”: When encoding parameters are accepted, starts to encode immediately.
#  Default value: no
#
postpone=no


 # Set to “no” to skip previewing the clip before encoding it.
#  This plays the source file, as it will be clipped. (If the video is to be
#  cropped, ignore the subtitle placement.)
#
show_preview=yes


 # Set to “no” to skip playing the encoded clip.
#
show_encoded_file=yes


 # List of presets
#  Each line corresponds to one Nadeshiko configuration file. Create custom
#    configurations to switch between them on the fly in Nadeshiko-mpv.
#    Read about file naming rules on the wiki: https://git.io/fx3Qr.
#  May be empty, in this case an item named “default” is created and assigned
#    “nadeshiko.rc.sh” as the value.
#  Format: [name for display]='nadeshiko-custom.rc.sh'
#
nadeshiko_presets=(
	# [default]='nadeshiko.rc.sh'
	# [H.264]='nadeshiko-H.264.rc.sh'
	# [VP9]='nadeshiko-VP9.rc.sh'
)


 # Which preset tab the GUI should open by default
#  If there are more than one nadeshiko preset defined, this opion defines
#    which preset will be opened by default, when GUI spawns.
#  The value must be a preset name, as defined in square brackets in the
#    nadeshiko_presets array above. In case when there is only one preset
#    in use, there will be no tabs, and hence this option will have no effect.
#  Default value: 'default'
#
#gui_default_preset='default'


 # Calculate and show, how the video clip would fit in each of the known file
#    sizes from all presets, before encoding it.
#  Purposes
#    1. When the file doesn’t fit, you can cancel the encoding before you see
#       an error and maybe cut a shorter clip instead.
#    2. To see, when encoding with VP9 is reasonable, and when you may
#       save time choosing H.264:
#        ⋅ sometimes VP9 allows to avoid downscaling, when H.264 would
#          require it – to fit in the maximum size with a good quality;
#        ⋅ when the duration happens to be so big, that with H.264 it isn’t
#          possible to encode it at all – only with VP9.
#  Predictor takes some time to run, but most of that time goes on determining
#    scene complexity, and this would be done anyway at the encoding stage.
#    Predictor just does it beforehand – and does it only once per each clip.
#    Read about how predictor works on the wiki: https://git.io/fxnJX
#  Reasons to disable:
#    - you use only “unlimited” size;
#    - you encode only the tiniest clips, which always fit
#      in your size constraints.
#  Default value: on
#
predictor=on


 # To save time, predictor runs only for the default maximum size (that is
#    specified in max_size_default variable in Nadeshiko RC file). This redu-
#    ces the number of runs threefold.
#  Format: all size codes used in the Nadeshiko RC file: tiny, small, normal,
#    unlimited, default.
#  Size “unlimited” can be omitted, as predictor never actually runs for
#    this size (everything fits in unlimited size).
#  Size “default” will enable predictor for whatever maximum size is set
#    as maximum_size_default in the Nadeshiko configuration file.
#    (It is not an error, if it will be set to “normal” and both “default”
#    and “normal” would be specified here.)
#  Default value: =( "default" )
#
run_predictor_only_for_sizes=(
	default
	# tiny
	# small
	# normal
)


 # Tells Nadeshiko-mpv to be quicker
#  After asking for crop settings immediately stores a postponed job
#  with the Nadeshiko preset specified in quick_run_preset. It also:
#  - disables building GUI;
#  - disables predictor;
#  - enables “postpone”.
#  Default value: off
#
quick_run=off


 # Nadeshiko preset to use, when quick_run option is enabled.
#  Must be either a preset file name in the config directory, or an empty
#    string to let Nadeshiko use the default settings.
#  Quick run ignores entries from nadeshiko_presets.
#
quick_run_preset=''