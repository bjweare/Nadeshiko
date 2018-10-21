# nadeshiko-mpv.rc.sh v2.3


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
#  After assigning mpv path to its socket, place it here.
#
mpv_sockets=(
	[Usual]='/tmp/mpv-socket'
)


 # Set to “no” to skip previewing the clip before encoding it.
#  This plays the source file, as it will be clipped.
#
show_preview=yes


 # Set to “no” to skip playing the encoded clip.
#  This plays an actually encoded file.
#
show_encoded_file=yes


 # List of presets
#  Each line corresponds to one Nadeshiko configuration file. Create custom
#    configurations to switch between them on the fly in Nadeshiko-mpv.
#    Read about file naming rules on the wiki: https://git.io/fx3Qr.
#    The order of presets in the GUI will correspond to the order here,
#    and the topmost preset here will be the default tab opened in the GUI.
#  Format: [name for display]='nadeshiko-custom.rc.sh'
#
nadeshiko_presets=(
	[default]='nadeshiko.rc.sh'
	# [H.264]='nadeshiko-H.264.rc.sh'
	# [VP9]='nadeshiko-VP9.rc.sh'
)


 # Which preset tab the GUI should open by default
#  The value must be a preset name, as defined in square brackets above.
#  In case when there is only one preset in use, there will be no tabs,
#  and hence this option would have no effect.
#
gui_default_preset='default'


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
#  Default value: yes
#
predictor=yes


 # To save time, predictor runs only for the default maximum size (that is
#    specified in max_size_default variable in Nadeshiko RC file). This redu-
#    ces the number of runs threefold.
#  Usually the only values, that are really helpful are for the default
#    maximum sizes, specified in the presets. The others are nice to look at,
#    but they only take time. However, you may add other sizes, if you wish.
#  Format: all size codes used in a Nadeshiko RC file: tiny, small, normal,
#    unlimited, default.
#  Size “unlimited” can be omitted, as predictor never actually runs for
#    this size (everything fits in unlimited size).
#  Size “default” will enable predictor for whatever maximum size is set
#    as maximum_size_default in the Nadeshiko configuration file aka preset.
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