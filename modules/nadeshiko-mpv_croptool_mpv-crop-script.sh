#  Should be sourced.

#  nadeshiko-mpv_croptool_mpv-crop-script.sh
#  Implementation of a cropping module for Nadeshiko-mpv
#  using mpv_crop_script.lua by TheAMM. Hacks over hacks.
#  deterenkelt © 2018
#
#  For licence see nadeshiko.sh


CROPTOOL_NAME='mpv_crop_script.lua'
REQUIRED_UTILS+=( inotifywait )

croptool_path="$LIBDIR/mpv_crop_script/mpv_crop_script.lua"



is_crop_tool_available() {
	[ -r "$croptool_path" ]
	return $?
}


prepare_crop_tool() {
	declare -g croptool_path
	local new_croptool_path="$TMPDIR/${croptool_path##*/}"
	cp -v  "$croptool_path" "$new_croptool_path"
	croptool_path="$new_croptool_path"
	cat <<-EOF >"$TMPDIR/if_croptool_fails_code.lua"
	file = io.open("$TMPDIR/croptool_failed", "w")
	file:write("mpv_crop_script couldn’t create temporary screenshot")
	file:close()
	EOF
	cat <<-EOF >"$TMPDIR/if_croptool_cancels_code.lua"
	file = io.open("$TMPDIR/croptool_cancelled", "w")
	file:write("mpv_crop_script cancelled cropping (ESC pressed)")
	file:close()
	EOF
	sed -ri " # Change script name
	         #  mpv_crop_script → mpv_crop_script_for_nadeshiko
	         #
	         s/^(.*\sSCRIPT_NAME\s*=\s*\"mpv_crop_script)(\"\s*)$/\1_for_nadeshiko\2/


	          # Change the name of the command, that script runs to crop
	         #  crop-screenshot → crop-screenshot-for-nadeshiko
	         #
	         s/^(.*\sSCRIPT_HANDLER\s*=\s*\"crop-screenshot)(\"\s*)$/\1-for-nadeshiko\2/


	          # Specify output file name
	         #  <unpredictable path> → TMPDIR/croptool_W:H:X:Y.jpg
	         #
	         s~^(.*\"output_template\",\s*\")[^\"]+(\".*)$~\1$TMPDIR/croptool_\${crop_w}:\${crop_h}:\${crop_x}:\${crop_y}.jpg\2~


	          # Specify output image format
	         #  As we only need the file name, choose faster method
	         #  png → mjpeg
	         #
	         s/^(.*\"output_format\",\s*\")[^\"]+(\".*)$/\1mjpeg\2/


	          # Disabling the default keybind to avoid clashing with the script,
	         #  that may be already installed in user’s mpv config directory.
	         #  false → true
	         #
	         s/^(.*\"disable_keybind\",\s*)[TRUEFALStruefals]+(.*)$/\1true\2/


	          # Removing an unnecessary warning about \${ext} in output_format.
	         #  It may confuse the users, but it is really unimportant.
	         #  true → false
	         #
	         s/^(.*\"warn_about_template\",\s*)[TRUEFALStruefals]+(.*)$/\1false\2/


	          # In case when mpv_crop_script would have an error, and couldn’t
	         #  create the file, remove the command, that sends unhelpful
	         #  to the user OSD message (there will be Nadehsiko’s own anyway,
	         #  and one message for one error is enough), and instead place
	         #  the code, that would make Nadeshiko-mpv stop waiting
	         #  and quit with an error message.
	         #
	         /mp\.osd_message\(\"Unable to save screenshot\"\)/ {
	             s/.*//
	             r $TMPDIR/if_croptool_fails_code.lua
	         }


	          # If user presses ESC (even though they should use ENTER),
	         #  convey the cancellation to Nadeshiko.
	         #
	         /^function ASSCropper:stop_crop\(clear\)/,/^end/ {
	             /self.current_crop = nil/ {
	             	 s/.*/&\n/
	                 r $TMPDIR/if_croptool_cancels_code.lua
	             }
	         }


	          # Remove superfluous OSD hints from the screen. It’s important
	         #    to hide the ESC keybind from the user, because what he wants
	         #    is ENTER – even for cancellation(!).
	         #  By default, mpv_crop_script remembers old crop coordinates
	         #    somewhere, and when called for the second time, it restores
	         #    the frame. And here is the important difference between
	         #    how ENTER works and how ESC works:
	         #    - by pressing ENTER mpv_crop_script “accepts” the old
	         #      not working crop frame and does nothing. Screen is ready
	         #      to accept the new selection.
	         #    - ESC key however, cancels the cropping with an OK result.
	         #      The user would have to run the whole process over again.
	         #      (That’s actually not as bad as it could be – if Nadeshiko
	         #      wasn’t altering the ESC path in mpv_crop_script.lua,
	         #      pressing it would just stop cropping, leave paused mpv
	         #      fullscreen and a hanging Nadeshiko-mpv process in the
	         #      background – Nadeshiko-mpv would wait for at least some
	         #      result, i.e. croptool_* file to appear in TMPDIR, and it
	         #      would wait for it infinitely.)
	         #
	         /^\s*fmt_key\(\"ENTER\",\s*\"Accept crop\"\)/ {
	             :begin
	             N
	             s/^.*\}\s*$/&/; T begin
	             :print
	             s/^(\s* fmt_key\(\"ENTER\",\s*\"Accept crop\"\)).*}$/\1\n    }/
	         }
	         /mp\.osd_message.*Took screenshot/d
	         /mp\.osd_message.*Crop canceled/d
	         " \
		"$croptool_path"
	return 0
}


run_croptool_installer() {
	# chmod +x "$LIBDIR/mpv-crop-script_installer.sh"
	# "$LIBDIR/mpv-crop-script_installer.sh" || return $?
	# send_command 'load-script' "$mpv_confdir/scripts/mpv_crop_script.lua" \
	# 	|| return $?
	return 0
}


run_crop_tool() {
	unset       croptool_resp_cancelled  croptool_resp_failed \
	            croptool_resp_width  croptool_resp_height  \
	            croptool_resp_x  croptool_resp_y
	declare -g  croptool_resp_cancelled  croptool_resp_failed \
	            croptool_resp_width  croptool_resp_height  \
	            croptool_resp_x  croptool_resp_y \
	            phantom_mpv_delay
	: ${phantom_mpv_delay:=0}
	local       s  mpv_processes_number

	set_prop 'fullscreen' 'yes'
	get_props 'cursor-autohide' \
	          'cursor-autohide-fs-only'
	set_prop 'cursor-autohide' 'no'
	set_prop 'cursor-autohide-fs-only' 'no'
	send_command 'load-script' "$croptool_path"
	#  Forks to background immediately.
	#  The module should set the (variable with) dialog text.
	# show_dialogue_cropping "Select an area, then press ENTER."
	info 'Launching crop tool.'

	#  See the comment to this variable in mpv_ipc.sh.
	local MPV_IPC_CHECK_SOCKET_ASSUME_ONE_PROCESS=t
	send_command 'script-binding' 'crop-screenshot-for-nadeshiko'

	while  read -r ; do
		#  “croptool_123:345:567:789.jpg” file is to be created by a crop tool.
		#    It must appear, if the user selected a crop area.
		#  “croptool_123:345:567:789.jpg_full.png” is a temporary file,
		#    a full-size screenshot, that mpv_crop_script creates first,
		#    and then crops it to the image file specified in the output_format
		#    option inside the lua file. Since inotifywait has problems with
		#    receiving (or reacting to) SIGPIPE when it runs within a subshell,
		#    and we avoid using --monitor for this reason, we wait for this
		#    file to appear instead of the “proper” file, that is actually
		#    cropped. In fact, this is faster.
		#  “croptool_cancelled” file should be created, if we would manage
		#    to display Nadeshiko-mpv window over mpv, and the user could
		#    press Cancel button to stop waiting for the proper file to appear.
		#    E.g. in case of croptool failing to create a croptool_1:2:3:4.jpg,
		#    but returning with code 0.
		#  “croptool_failed” is used to catch croptool error from within
		#    the tool itself.
		[[ "$REPLY" =~ ^croptool_(cancelled|failed|([0-9]+):([0-9]+):([0-9]+):([0-9]+)\.jpg_full.png)$ ]] && {
			case "${BASH_REMATCH[1]}" in
				cancelled)
					croptool_resp_cancelled=t
					;;
				failed)
					croptool_resp_failed=t
					;;
				*)
					croptool_resp_width="${BASH_REMATCH[2]}"
					croptool_resp_height="${BASH_REMATCH[3]}"
					croptool_resp_x="${BASH_REMATCH[4]}"
					croptool_resp_y="${BASH_REMATCH[5]}"
					;;
			esac
			# pkill -PIPE --session 0 --pgroup 0  -f inotifywait
			break
		}
	done < <(inotifywait -q --format %f  -e create  "$TMPDIR") ||:
	#                       ^ not using --monitor here, somehow it gulps
	#                         SIGPIPE and doesn’t quit.
	set_prop 'fullscreen' 'no'
	set_prop 'cursor-autohide' "$cursor_autohide"
	set_prop 'cursor-autohide-fs-only' "$cursor_autohide_fs_only"
	return 0
}


 # For when the script in user’s mpv_confdir/scripts was used
#
# backup_croptool_config() {
# 	declare -g croptool_config_backup
# 	if [ -r "$croptool_config" ]; then
# 		info 'Backing up crop tool config.'
# 		#  Backup must have a name, that mpv wouldn’t accidentally pick.
# 		croptool_config_backup="${croptool_config%/*}"
# 		croptool_config_backup+="/__backup_"
# 		croptool_config_backup+="${croptool_config##*/}__$(date +%F__%T)"
# 		mv "$croptool_config" "$croptool_config_backup"
# 	else
# 		return 0
# 	fi

# 	return 0
# }


# restore_croptool_config() {
# 	declare -g croptool_config_backup
# 	if [ -v croptool_config_backup ] && [ -r "$croptool_config_backup" ]; then
# 		info 'Restoring crop tool config.'
# 		mv "$croptool_config_backup" "$croptool_config"
# 		unset croptool_config_backup
# 	else
# 		return 0
# 	fi

# 	return 0
# }


 # If the script would break before restore_croptool_config would normally
#  run, call it from this hook, that is executed from Nadeshiko-mpv own
#  on_error().
on_croptool_error() {
	# [ -v croptool_config_backup ] && restore_croptool_config
	pkill -PIPE --session 0 --pgroup 0  -f inotifywait ||:
	return 0
}


return 0




 # Notes about how it should have been, but could not be implemented.
#
#  Ideally, once the user clicks on “Pick” button to start cropping tool,
#    it would go the following way:
#    - mpv goes fullscreen;
#    - cursor changes its shape into a cross;
#    - Nadeshiko “Cropping” dialog remains in the corner on top of mpv,
#      in the dialog Nadeshiko tells the user expected actions: “Select
#      an area, then press Enter.” The dialog could be moved with mouse,
#      if it would meddle with cropping, but usually it wouldn’t take
#      a big space.
#
#  The troubles:
#
#    Following the specs[1], mpv window in fullscreen is shown on top
#    of all other windows, even those that have  _NET_WM_STATE_ABOVE hint
#    set. That means that to have a Nadeshiko-mpv dialog on top of mpv
#    in fullscreen is impossible. However, there are two ways to avoid this:
#
#     - Do not set mpv fullscreen, make it stay a window and place it so
#       it would take the whole desktop.
#
#       Trouble 1
#
#       This will not work in tiling WMs, as there is no common way to untile
#       a window or at least tell, if it’s tiled at all. There are WM-specific
#       window hints, but doing it for every possible WM is a nearly
#       impossible task.
#
#       But tiling WMs should and commonly not tile windows with window type
#       “dialog”! If we temporarily change mpv window type to dialog, the
#       window manager should automatically untile it!
#
#       $ xprop -id $dialog_wid  -f _NET_WM_WINDOW_TYPE 32a  \
#               -set _NET_WM_WINDOW_TYPE _NET_WM_WINDOW_TYPE_DIALOG
#
#       Trouble 2
#
#       This changes a window type, but i3wm seems to make a decision on
#       whether a window should be tiled or floating at the time, when the
#       window is mapped. Changing the type after the window is shown
#       doesn’t make the WM unfloat that window.
#
#       The-en we must somehow tell the WM to redraw, remap or reshow it!
#
#       There is a hint(?) _NET_RESTACK_WINDOW, that is sent to the root
#       window, and it should reapply stacking (i.e. window ordering)
#       for a given window.[2]
#
#       Trouble 3
#
#       _NET_RESTACK_WINDOW takes four arguments. The first one must be “2”,
#       the second is supposedly the window ID, the third one has no descrip-
#       tion and the fourth one shold be zero (or empty?). Xprop manual page
#       doesn’t describe, how one is supposed to pass more than one value
#       to a property. Its -set parameter doesn’t take more than two arguments.
#
#       $ xprop -id $root_wid -f _NET_RESTACK_WINDOW 32cccc \
#               -set _NET_RESTACK_WINDOW  "2  $dialog_wid  0 0"
#
#       – this isn’t working.
#
#
#     - Make Nadeshiko-mpv dialog a child window of mpv!
#       We can successfully change options WM_TRANSIENT_FOR
#       and WM_CLIENT_LEADER for Nadeshiko dialog window.
#
#       $ xprop -id $dialog_wid -f WM_TRANSIENT_FOR 32c  \
#               -set WM_TRANSIENT_FOR $mpv_wid
#
#       $ xprop -id $dialog_wid -f WM_CLIENT_LEADER 32c  \
#               -set WM_CLIENT_LEADER $mpv_wid
#
#       Trouble 4
#
#       It isn’t enough to make a dialog stay above mpv, when it is fullscreen.
#
#
#  The code to retrieve the variables
#
#   root_wid_hex=$(
#   	xwininfo -root -children -all \
#   		| sed -rn 's/.*Root window id: 0x([0-9a-f]+) .*/\1/p'
#   )
#   root_wid=$(( 16#$root_wid_hex ))
#
#   mpv_pid=$(pgrep -f '/usr/bin/mpv')
#   mpv_wid=$(xdotool search --all --pid "$mpv_pid" --onlyvisible)
#
#   dialog_pid=$(pgrep -f python3)
#   dialog_wid=$(xdotool search --all --pid "$dialog_pid" --onlyvisible)


#  [1] https://specifications.freedesktop.org/wm-spec/wm-spec-1.3.html#STACKINGORDER
#  [2] https://specifications.freedesktop.org/wm-spec/wm-spec-1.3.html#idm140130317630816