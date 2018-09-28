# nadeshiko-mpv.rc.sh v2.1


 # The command to launch mpv.
#
mpv="mpv"

 # Dialog program to use
#  Either “Xdialog” or “kdialog”.
#  Default value: Xdialog
#
dialog='Xdialog'

 # Hide the dialogue asking for a custom video name.
#  Only for dialog=kdialog. Because kdialog cannot ask subtly,
#  and this gets annoying.
#
show_name_setting_dialog=yes

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
#  See “Multiple configs and switching on the fly”
#  in the wiki: https://github.com/deterenkelt/Nadeshiko/wiki/Tips
#
nadeshiko_configs=(
	'nadeshiko.rc.sh'
	# 'my-custom-config-for-mp4.rc.sh'
)
