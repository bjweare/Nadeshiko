#  Should be sourced.

#  09_encode.sh
#  Nadeshiko module that selects and runs a codec-specific encoding module.
#  It is mostly an empty conveyor, but it also defines two functions to
#  display a progressbar in the console during the encoding process.
#  (The functions are to be used by the codec-specific encoding modules.)
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh



 # Launches a coprocess, that will read ffmpeg’s progress log and report
#  progress information to console.
#
launch_a_progressbar_for_ffmpeg() {
	[ -v ffmpeg_progressbar ] || return 0
	#  ffmpeg_progress_log must be defined before the check on whether
	#  console output should be prevented.
	declare -g  ffmpeg_progress_log="$TMPDIR/ffmpeg_progress.log"
	declare -g  progressbar_pid
	declare -g  frame_count

	#  Must be checked AFTER $ffmpeg_progress_log is set!
	[ -v do_not_report_ffmpeg_progress_to_console ] && return 0

	local  progress_status
	local  frame_no
	local  elapsed_time

	export frame_count

	mkfifo "$ffmpeg_progress_log"
	#  Turning the cursor invisible
	tput civis

	{
		coproc {
			#  Wait for ffmpeg process to appear.
			until pgrep --session 0  -f ffmpeg  \
			      && [ -r "$ffmpeg_progress_log" ]
			do
				sleep 1
			done

			line_length=$(( TERM_COLS - ${#__mi} - 2 ))
			#  Avoid hitting the terminal border --^
			readiness_pct='100% '
			progressbar_chars='[=>-]'
			pbar_char_opbracket=${progressbar_chars:0:1}
			pbar_char_done=${progressbar_chars:1:1}
			pbar_char_processing=${progressbar_chars:2:1}
			pbar_char_to_be_done=${progressbar_chars:3:1}
			pbar_char_closbracket=${progressbar_chars:4:1}
			progressbar_length=$(( $line_length - ${#readiness_pct} - 2 ))
			#                      opening and closing brackets  -----^

			#  Leave an empty line from the corprocess pid printed by shell.
			echo

			exec {ffmpeg_progress_log_fd}<>"$ffmpeg_progress_log"


			until [ "${progress_status:-}" = end ]; do
				read -r -u "$ffmpeg_progress_log_fd"

				case "$REPLY" in

					progress=*)  #  → $progress_status

						[[ "$REPLY" =~ ^progress=(continue|end)$ ]]  \
							&& progress_status=${BASH_REMATCH[1]}  \
							|| err "FFmpeg returned an unknown value for the key “progress”: “${REPLY#progress=}”."
						;;

					frame=*)  #  → $frame_no

						#  Stripping the leading zeroes just in case
						[[ "$REPLY" =~ ^frame=([0]*)([0-9]+)$ ]]  \
							&& frame_no=${BASH_REMATCH[2]}  \
							|| err "FFmpeg returned an unknown value for the key “frame”: “${REPLY#frame=}”."
						;;

					out_time=*)  #  → $elapsed_time

						if [[ "$REPLY" =~ ^out_time=([0-9\:]+\.[0-9]{3})[0-9]*$ ]]; then
							 is_valid_timestamp "${BASH_REMATCH[1]}"  \
								 && elapsed_time="${BASH_REMATCH[1]}"  \
								 || out_time_has_an_unknown_value=t
						else
							out_time_has_an_unknown_value=t
						fi
						[ -v out_time_has_an_unknown_value ]  \
							&& err "FFmpeg returned an unknown value for the key “out_time”: “${REPLY#out_time=}”."
						;;

				esac

				[ "${progress_status:-}" = end ] && frame_no=$frame_count
				[ -v frame_no ] || continue

				#  Exporting it for the subshell with printf
				export frame_no

				#  Caret return.
				echo -en "\r"

				#  Message indentation.
				echo -n "$__mi"

				#  Readiness.
				readiness_pct="$(printf '%3d' $(( frame_no * 100 / frame_count )))"
				echo -n "${readiness_pct}% ["

				 # Assembling a line of blocks, that represent what is done.
				#    Literally, how much characters the done blocks comprise
				#    in the progressbar.
				#  Also avoiding the bug, when the encoding is finished,
				#    but the bar ends with ==>-]
				#
				if (( readiness_pct == 100 )); then
					blocks_done_no=$progressbar_length

				elif (( readiness_pct < 100 )); then
					blocks_done_no=$(( frame_no * progressbar_length / frame_count ))

				elif (( readiness_pct > 100 )); then
					#  A bug was reported, when readiness has exceeded the
					#  $frame_count in the clip. For this bug the bar should
					#  have the “progress going” block (usually ‘>’), so the
					#  bar should end like '…======>?  '
					blocks_done_no=$(( progressbar_length -1 ))
				fi

				 # The last block done (the last ‘=’) will be replaced with
				#  the progress block (i.e. ‘>’), so it is necessary to have
				#  at least one block here. (Otherwise a line like ‘------’)
				#  may confuse the user into thinking, that ffmpeg cannot
				#  start for some reason.
				#
				(( blocks_done_no == 0 )) && blocks_done_no=1
				blocks_done_chars=''
				for (( i=0; i<blocks_done_no-1; i++ )); do
					blocks_done_chars+='='
				done
				(( readiness_pct == 100 ))  \
					&& blocks_done_chars+='='  \
					|| blocks_done_chars+='>'
				echo -n "$blocks_done_chars"

				 # Now assembling the string of blocks that are “to be done”.
				#
				blocks_to_be_done_no=$(( progressbar_length - blocks_done_no ))
				blocks_to_be_done_chars=''
				for (( i=0; i<blocks_to_be_done_no; i++ )); do
					blocks_to_be_done_chars+='-'
				done
				echo -n "$blocks_to_be_done_chars"

				 # Avoiding the bug with the percentage exceeding 100.
				#  Why it exceeds 100% is not yet known – the reporter didn’t
				#  provide sufficient information about the case.
				#
				(( readiness_pct <= 100 ))  \
					&& echo -n ']'  \
					|| echo -n '?'

			done


			 # Jumping off from the line with progress bar and making
			#  an empty line after the bar, symmetric to the empty line above.
			#  (The line above is necessary to avoid clutter caused by printed
			#  (co)process id.)
			#
			echo -en '\n\n'
			exit 0
		} >&${STDOUT_ORIG_FD} 2>&${STDERR_ORIG_FD}
	} || true   #  errors in progressbar are not critical.
	progressbar_pid=$!
	return 0
}


stop_the_progressbar_for_ffmpeg() {
	[ -v ffmpeg_progressbar ] || return 0
	[ -v do_not_report_ffmpeg_progress_to_console ] && return 0
	local i
	#  Wait for a maximum of five seconds for progressbar coprocess to finish.
	for ((i=0; i<5; i++)); do
		[ -e /proc/$progressbar_pid ] && sleep 1 || break
	done
	#
	#  Progressbar process might quit by itself, but if it did not,
	#  it has to be killed. The “echo” is for the output to jump off
	#  the line with the progressbar, because if kill has succeeded,
	#  the function can’t do it, obviously.
	#
	if [ -e /proc/$progressbar_pid ]; then
		(( $(get_bahelite_verbosity console) >= 5 ))  \
			&& info 'After 5 seconds, progressbar subprocess is still running.'
		if kill -TERM $progressbar_pid 2>/dev/null; then
			echo
			(( $(get_bahelite_verbosity console) >= 5 ))  \
				&& info 'Killed progressbar process.'
		else
			(( $(get_bahelite_verbosity console) >= 5 ))  \
				&& info "Progress bar finished by itself after $i seconds in the last moment."
		fi
	else
		(( $(get_bahelite_verbosity console) >= 5 ))  \
			&& info "Progress bar finished by itself after $i seconds."
	fi
	rm -f "$ffmpeg_progress_log"
	#  Turning the cursor visible again
	tput cnorm
	return 0
}


encode() {
	milinc
	if [ "$(type -t encode-$ffmpeg_vcodec)" = 'function' ]; then
		encode-$ffmpeg_vcodec
	else
		err "Cannot find encoding function “encode-$ffmpeg_vcodec”."
	fi

	mildec
	return 0
}


return 0