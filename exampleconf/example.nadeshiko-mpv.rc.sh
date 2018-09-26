# nadeshiko-mpv.rc.sh v2.0


 # The command to launch mpv.
#
mpv="mpv"


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


 # Nadeshiko configs
#  Add an alternative config file, and before the encoding starts,
#  Nadeshiko-mpv will display a menu, which will let to choose a particular
#  configuration file for Nadeshiko.
#  See also:
#
nadeshiko_configs=(
	'nadeshiko.rc.sh'
	# 'my-custom-config-for-mp4.rc.sh'
)
