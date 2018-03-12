# nadeshiko-mpv.rc.sh

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
mpv_socket="/tmp/mpv-watchsh-socket"

 # Comment to skip previewing the clip BEFORE encoding it.
#  This plays the source file, as it will be clipped.
#
show_preview=t

 # Comment to skip playing the encoded clip.
#  This plays an actually encoded file.
#
show_post_preview=t
