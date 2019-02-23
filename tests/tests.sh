#! /usr/bin/env bash

#  tests.sh
#  Test to see check how parameters applied and to ensure,
#  that the resulting file is what it should be.
#  deterenkelt © 2018

#  WTFPL

set -feE
. "$(dirname "$0")/../lib/bahelite/bahelite.sh"
. "$(dirname "$0")/../lib/gather_file_info.sh"
MY_DESKTOP_NAME="Nadeshiko test suite"
nadeshiko_dir="$MYDIR/.."
exampleconf_dir="$MYDIR/../exampleconf"
config_dir="$HOME/.config/nadeshiko"

nadeshiko="$nadeshiko_dir/nadeshiko.sh"
nadempv="$nadeshiko_dir/nadeshiko-mpv.sh"
rcfile="$config_dir/nadeshiko.rc.sh"
nadempv_rcfile="$config_dir/nadeshiko-mpv.rc.sh"
example_rcfile="$exampleconfdir/example.nadeshiko.rc.sh"
example_nadempv_rcfile="$exampleconfdir/example.nadeshiko-mpv.rc.sh"

tests_dir="$MYDIR/TESTS/$("$nadeshiko" --version | sed -rn '1s/.*\s(\S+)$/\1/p')"
source_sets="$MYDIR/tests_source_sets.sh"
mkdir -p "$tests_dir"

[ -r "$source_sets" ] || {
	cat <<-EOF >&2
	$source_sets wasn’t found!
	The tests in this file need these sets to be defined. The file should
	  contain bash arrays – name of the array becomes the name of a set –
	  with three items defined:
	  [0] – absolute path to a video file;
	  [1] – start time of the slice;
	  [2] – stop time of the slice.
	Example:
	bales_surprised_face=(
	    '/home/video/Talian.mkv'
	    '1:11:43.291'
	    '1:11:47.291'
	)
	EOF
	err "Create source sets first."
}
. "$source_sets"


#  Backup RC file, put our test dummy.
[ -e "$rcfile" ] && {
	mv "$rcfile" "$rcfile.yuzyanoerusi.bak"
	mv "$nadempv_rcfile" "$nadempv_rcfile.yuzyanoerusi.bak"
	moved_rcfiles=t
}
#  And always return it back on exit
on_exit() {
	#  But only if we actually moved it – don’t overwrite it by an accident.
	[ -v moved_rcfiles ] && {
		mv "$rcfile.yuzyanoerusi.bak" "$rcfile"
		mv "$nadempv_rcfile.yuzyanoerusi.bak" "$nadempv_rcfile"
	}
	rm -f 't'
	return 0
}

 # Changes a parameter in $rcfile.
#  $1 – parameter name
#  $2 – parameter value
#
change_in_rc() {
	local param_name="$1" param_val="$2"
	grep -qE "^\s*#?\s*$param_name=.*" "$rcfile" \
		|| err "$FUNCNAME: No such parameter – “$param_name”."
	sed -ri "s/^\s*#?\s*$param_name=.*/$param_name=$param_val/" "$rcfile"
	[ $? -ne 0 ] \
		&& err "$FUNCNAME: Couldn’t change “$param_name” to “$param_val” – sed error."
	return 0
}

prepare_test() {
	#  By default, take $test_NN_desc as description. Tests with internal
	#  subtests (13.a, 13.b, 13.c…) may call prepare_test before each such
	#  subtest and pass a custom description.
	#  That description is passed via $1.
	local test_description="${1:-}" desc
	unset fname_prefix
	if [ "$test_description" ]; then
		fname_prefix="test_${test_description%% *}"
	else
		declare -n desc="${FUNCNAME[1]}_desc"
		test_description="${FUNCNAME[1]#test_}.  $desc"
		fname_prefix=${FUNCNAME[1]}
	fi
	echo
	info "${__bri}$test_description${__s}"
	declare -g where_to_place_new_file="$tests_dir"
	set +f
	#  Removing old files. If the test wouldn’t generate new file(s),
	#  there should be no files – old ones shouldn’t be confused with the new.
	rm -f "$tests_dir/$fname_prefix"* ||:
	set -f
	cp "$example_rcfile" "$rcfile"
	cp "$example_nadempv_rcfile" "$nadempv_rcfile"
	[ -r "${source_set[0]}" ] \
		|| err "Source video not a readable file: “${source_set[0]}”."
	#  Encoded file shouldn’t be older than this file.
	#  This is to be sure, that the file mentioned in the last log
	#  is the real file, and not some old encoded file.
	touch t
	return 0
}

 # Call nadeshiko.sh
#  Passes common parameters: source file and times, directory, where to place
#  encoded file, file name prefix “test_NN” and custom parameters.
#  [$1..n] – custom parameters.
#
encode() {
	"$nadeshiko" "${source_set[@]}" \
	             "fname_pfx=$fname_prefix" \
	             "$where_to_place_new_file" \
	             "$@"
}

get_last_encoded_file() {
	local last_log last_file
	read_last_log 'nadeshiko' || {
		warn "Cannot get last log."
		return 1
	}
	last_file=$(sed -rn '/Encoded successfully/ {n; s/^..//p}' <<<"$LAST_LOG")
	popd >/dev/null
	echo "$last_file"
	return 0
}

post_test() {
	unset new_file file_created
	declare -g new_file="$where_to_place_new_file/$(get_last_encoded_file)"
	if [ -r "$new_file" ]; then
		[ "$new_file" -nt ./t ] && declare -g file_created=t || {
			warn "No file created."
			return 8
		}
	else
		warn "No such file: “$new_file”."
		return 8
	fi
	gather_file_info "$new_file" ${FUNCNAME[1]#test_}
	return 0
}

play_encoded_files() {
	local f
	info "Encoding seems to be complete.
	      Press any key to play files > "
	read -n1
	set +f
	for f in "$tests_dir/${FUNCNAME[1]}"* ; do
		mpv --loop-file "$f"
	done
	set -f
	return 0
}

 # Ask, if the test was successfull or not.
#  The result is a variable test_NN_result, which contains either “OK”
#  or “Fail” – it will be shown in the main menu.
#  $1 – a text describing conditions. It better have newlines.
#
ask_if_ok() {
	local conditions="$1" test_no="${FUNCNAME[1]}"
	local lines=$( echo "$conditions" | wc -l )
	local xdialog_window_height=$((  116 + 27 * $lines  ))
	errexit_off
	if Xdialog --title "$MY_MSG_TITLE" \
	           --ok-label "OK" \
	           --cancel-label="Cancel" \
	           --buttons-style default \
	           --yesno "$conditions" \
	           324x$xdialog_window_height
	then
		declare -g ${test_no}_result=OK
	else
		declare -g ${test_no}_result=Fail
	fi
	errexit_on
	return 0
}


 #
  #  Below several dozens of test cases are grouped into several sets.
  #  Certain tests require specific input data, such as having subtitles
  #  and displaying them (there should be lines on the screen) on the time
  #  Nadeshiko should cut.
 #

 # Tests 01–04 are encoding samples, that go to wiki.
#  Readme.md points to that page.
#
test_01_desc='Animation, 4 seconds, 1080p'
test_01() {
	declare -gn source_set='anim_source_set1'
	prepare_test
	encode 'tiny' || exit $?
	post_test
	conditions="Playback, 1080p, audio"
	ask_if_ok "$conditions"
	return 0
}

test_02_desc='Animation, 4 minutes, 1080p'
test_02() {
	declare -gn source_set='anim_source_set2'
	prepare_test
	encode 'small' || exit $?
	post_test
	conditions="Playback, 1080p, audio"
	ask_if_ok "$conditions"
	return 0
}

test_03_desc='Film, 4 seconds, 1080p (orig. 818p), 6ch → 2ch'
test_03() {
	declare -gn source_set='film_source_set1'
	prepare_test
	encode 'tiny' || exit $?
	post_test
	conditions="Playback, 1080p, audio"
	ask_if_ok "$conditions"
	return 0
}

test_04_desc='Film, 4 minutes, 1080p (orig. 818p), 6ch → 2ch'
test_04() {
	declare -gn source_set='film_source_set2'
	prepare_test
	encode 'small' || exit $?
	post_test
	conditions="Playback, 1080p, audio"
	ask_if_ok "$conditions"
	return 0
}

test_05_desc='Animation, 2 seconds, 1080p'
test_05() {
	declare -gn source_set='anim_source_set2'
	prepare_test
	encode 'tiny' || exit $?
	post_test
	conditions="Playback, 1080p, audio"
	ask_if_ok "$conditions"
	return 0
}

test_06_desc='Animation, 2 seconds, 1080p → forced scale to 480p, vb12M, ab88k'
test_06() {
	declare -gn source_set='anim_source_set2'
	prepare_test
	encode 'tiny' '480p' || exit $?
	post_test
	echo
	[ "$file06_vbitrate" = "12000" ] \
		&& info "Vbitrate is 12M, as expected." \
		|| warn "Vbitrate is “$file06_vbitrate” k, shoud be 12000 k."
	[ "$file06_abitrate" = "88" ] \
		&& info "Abitrate is 88k, as expected." \
		|| warn "Abitrate is “$file06_vbitrate” k, shoud be 88 k."
	echo
	conditions="Playback, 480p, audio, v+a bitrates"
	ask_if_ok "$conditions"
	return 0
}

test_07_desc='Animation, 2 seconds, 1080p → default scale (in RC) to 720p'
test_07() {
	declare -gn source_set='anim_source_set2'
	prepare_test
	change_in_rc 'scale' '720p'
	encode 'tiny' || exit $?
	post_test
	conditions="Playback, 720p, audio"
	ask_if_ok "$conditions"
	return 0
}

test_08_desc='Nadeshiko-mpv, postpone encode, hardcoding external VTT subs'
test_08() {
	declare -gn source_set='kaguya_luna'
	prepare_test
	cat <<-EOF >>"$rcfile"
	new_filename_prefix=$FUNCNAME
	EOF
	info "This test will spawn an mpv instance.
	      Select Time1 and Time2 with a hotkey, that does postponed encode.
	      Repeat to make a second slice, 1–2 seconds is enough.
	      Press any key to contine > "
	read -n1
	local temp_sock="$(mktemp -u)"
	cat <<-EOF >"$nadempv_rcfile"
	# nadeshiko-mpv.rc.sh v1.2
	mpv_sockets=(  [Usual]='$temp_sock'  )
	EOF
	mpv --x11-name mpv-nadeshiko-preview \
	    --input-ipc-server="$temp_sock" \
	    --loop-file=inf \
	    --start=5 --pause \
	    --sub-file="${source_set[0]%.*}.en.vtt" \
	    --osd-msg1="Paused" \
	    "${source_set[0]}" || err 'mpv error'
	info "mpv has quit, let’s look if “./postponed” has commands…
	      Press any key to continue > "
	read -n1
	"$nadeshiko_dir/nadeshiko-do-postponed.sh" || exit $?
	#  post_test  will look for the files in $tests_dir, but we used
	#  nadeshiko-mpv instead of calling encode and nadeshiko.sh as usual.
	where_to_place_new_file="$PWD"
	post_test
	local new_file_name
	new_file_name=${source_set[0]##*/}
	new_file_name=${new_file_name[0]%.*}
	new_file_name="$PWD/$FUNCNAME $new_file_name"
	set +f
	mv "$new_file_name"* "$tests_dir"
	set -f
	play_encoded_files
	conditions="Playback, audio, subtitles"
	ask_if_ok "$conditions"
	return 0
}

test_09_desc='Time2 as seconds >59 (0–72 s), duration check, nosub, H264+AAC.'
test_09() {
	declare -gn source_set='yurucamp_72_seconds'
	prepare_test
	# Codecs
	change_in_rc 'ffmpeg_vcodec' 'libx264'
	change_in_rc 'ffmpeg_acodec' 'libfdk_aac'
	# We test duration, not quality here.
	change_in_rc 'libx264_preset' 'ultrafast'
	encode 'small' 'nosub' || exit $?
	post_test
	echo -e '\n'
	[ $file09_duration_total_s -eq 72 ] \
		&& info "Duration is 72 s." \
		|| warn "Duration is $file09_duration, should be 72 s."
	[ "$file09_vcodec" = AVC ] \
		&& info "Video codec is AVC." \
		|| warn "Video codec is $file09_vcodec, should be AVC."
	[ "$file09_acodec" = AAC ] \
		&& info "Audio codec is AAC." \
		|| warn "Audio codec is $file09_acodec, should be AAC."
	echo -e '\n'
	play_encoded_files
	conditions="duration = 1:12, nosub, H264+AAC"
	ask_if_ok "$conditions"
	return 0
}

test_10_desc='Fit to size: 10M with k=1000. 72 seconds, noaudio, VP9.'
test_10() {
	declare -gn source_set='yurucamp_72_seconds'
	prepare_test
	#  We test fitting to size, not quality here.
	#  Though if time would allow, it’d be better to test with a slower setup…
	#  -deadline for pass1 is set to “good”, because “realtime” somehow
	#  doesn’t produce the log needed for pass2. free_shrugs.tiff
	change_in_rc 'libvpx_pass1_deadline' 'good'
	change_in_rc 'libvpx_pass1_cpu_used' '8'
	change_in_rc 'libvpx_pass2_deadline' 'realtime'
	change_in_rc 'libvpx_pass2_cpu_used' '8'
	# max_q from the table will overshoot size on 54%.
	change_in_rc 'libvpx_min_q' '55'
	change_in_rc 'libvpx_max_q' '55'
	encode 'small' 'k=1000' 'noaudio' || exit $?
	post_test || err 'No file was encoded.'
	echo
	[ $file10_size_B -le $((10*1000*1000)) ] \
		&& info "Size fits in 10M with k=1000." \
		|| warn "File size DOES NOT fit 10M with k=1000."
	[ "$file10_vcodec" = VP9 ] \
		&& info "Video codec is VP9." \
		|| warn "Video codec is $file10_vcodec, should be VP9."
	info "Audio codec is “$file10_acodec” <-- should be empty."
	echo
	play_encoded_files
	conditions="duration = 1:12, VP9, noaudio, 10M with k=1000"
	ask_if_ok "$conditions"
	return 0
}

test_11_desc='Quit on high overshoot. Params are like for №10.'
test_11() {
	declare -gn source_set='yurucamp_72_seconds'
	prepare_test
	#  We test fitting to size, not quality here.
	#  Though if time would allow, it’d be better to test with a slower setup…
	#  -deadline for pass1 is set to “good”, because “realtime” somehow
	#  doesn’t produce the log needed for pass2. free_shrugs.tiff
	change_in_rc 'libvpx_pass1_deadline' 'good'
	change_in_rc 'libvpx_pass1_cpu_used' '8'
	change_in_rc 'libvpx_pass2_deadline' 'realtime'
	change_in_rc 'libvpx_pass2_cpu_used' '8'
	change_in_rc 'libvpx_max_q' '60'
	encode 'small' 'k=1000' 'noaudio' \
		|| info "It seems that no file was encoded!"
	echo
	conditions="Nadeshiko overshot size on more than 20% and quit."
	ask_if_ok "$conditions"
	return 0
}

test_12_desc='Redo encode on a <20% size overshoot. Params are like for №10.'
test_12() {
	declare -gn source_set='yurucamp_72_seconds'
	prepare_test
	#  We test fitting to size, not quality here.
	#  Though if time would allow, it’d be better to test with a slower setup…
	#  -deadline for pass1 is set to “good”, because “realtime” somehow
	#  doesn’t produce the log needed for pass2. free_shrugs.tiff
	change_in_rc 'libvpx_pass1_deadline' 'good'
	change_in_rc 'libvpx_pass1_cpu_used' '8'
	change_in_rc 'libvpx_pass2_deadline' 'realtime'
	change_in_rc 'libvpx_pass2_cpu_used' '8'
	change_in_rc 'libvpx_min_q' '7'
	change_in_rc 'libvpx_max_q' '37'
	encode 'small' 'k=1000' 'noaudio'
	echo
	conditions="Nadeshiko overshot size on 7% and redid encode 6 times
	(Overshooting rollercoaster problem caused by high cpu-used value)."
	ask_if_ok "$conditions"
	return 0
}

test_13_desc='Invalid input in various combinations. Nadeshiko shouldn’t encode.'
test_13() {
	declare -gn source_set='anim_source_set1'
	milinc

	prepare_test '13.a  Wrong Time2: 0.00:00'
	#                     This is OK --vv   v------ This is not.
	if "$nadeshiko" "${source_set[0]}" 10  0.00:00 \
	                "fname_prefix=${FUNCNAME[1]}" \
	                "$where_to_place_new_file"
	then
		warn "Fail – Time2 was wrong.
		      Nadeshiko shouldn’t have encoded anything."
	else
		info "No encode – as it should be!"
	fi

	prepare_test '13.b  Options that cannot be used together: noaudio and ab100k'
	#          vvvvvvv   vvvvvv
	if encode 'noaudio' 'ab100k'; then
		warn "Fail – “noaudio” and “ab100k” cannot be used together.
		      Nadeshiko shouldn’t have encoded anything."
	else
		info "No encode – as it should be!"
	fi

	prepare_test '13.c  Options that cannot be used together: NNNp and crop'
	#          vvvv   vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
	if encode "576p" "crop=$((1920/2)):120:200:$((1080/2))"; then
		warn "Fail – “NNNp” and “crop” cannot be used together.
		      Nadeshiko shouldn’t have encoded anything."
	else
		info "No encode – as it should be!"
	fi

	prepare_test '13.d  Wrong vcodec and acodec: hurr and durr'
	change_in_rc 'ffmpeg_vcodec' 'hurr'  # codec doesn’t exist
	change_in_rc 'ffmpeg_acodec' 'durr'  # codec doesn’t exist
	if encode; then
		warn "Fail – “hurr” and “durr” aren’t real codecs.
		      Nadeshiko shouldn’t have encoded anything."
	else
		info "No encode – as it should be!"
	fi

	prepare_test "13.e  Incompatible combination of real codecs and container:
	                    mp4 + libx264 + libvorbis"
	change_in_rc 'container'     'mp4'        # intermingling one of the two
	change_in_rc 'ffmpeg_vcodec' 'libx264'    # main sets
	change_in_rc 'ffmpeg_acodec' 'libvorbis'  # (mp4+libx264+aac)
	if encode; then
		warn "Fail – mp4, libx264 and libvorbis cannot be used together.
		      Nadeshiko shouldn’t have encoded anything."
	else
		info "No encode – as it should be!"
	fi

	prepare_test "13.f  Incompatible combination of codecs and container:
	                    webm + libvpx-vp9 + aac"
	change_in_rc 'container'     'webm'        # intermingling one of the two
	change_in_rc 'ffmpeg_vcodec' 'libvpx-vp9'  # main sets
	change_in_rc 'ffmpeg_acodec' 'aac'         # (webm+libvpx-vp9+libvorbis)
	if encode; then
		warn "Fail – webm, libvpx-vp9 and aac cannot be used together.
		      Nadeshiko shouldn’t have encoded anything."
	else
		info "No encode – as it should be!"
	fi

	prepare_test "13.g  Incompatible combination of codecs and container:
	                    webm + libtheora + libvorbis"
	change_in_rc 'container'     'webm'
	change_in_rc 'ffmpeg_vcodec' 'libtheora'  # exists, but not in the list
	change_in_rc 'ffmpeg_acodec' 'libvorbis'
	if encode; then
		warn "Fail – webm, libtheora and libvorbis cannot be used together.
		      Nadeshiko shouldn’t have encoded anything."
	else
		info "No encode – as it should be!"
	fi

	local ext_sub=$(mktemp -u)
	prepare_test "13.h  Pass external subtitles, which file doesn’t exist
	                    subs=$ext_sub"
	if encode "subs=$ext_sub" ; then
		warn "Fail – external subtitle file doesn’t exist.
		      Nadeshiko shouldn’t have encoded anything."
	else
		info "No encode – as it should be!"
	fi

	mildec
	echo
	info "All runs are complete.
	      Please verify, that Nadeshiko refused to encode
	      and press any key to continue > "
	read -n1
	conditions="No encodes. No warnings"
	ask_if_ok "$conditions"
	return 0
}

test_14_desc='Cropping'
test_14() {
	declare -gn source_set='slow_start_crop_to_subs'
	prepare_test
	#              South-west part with subtitles
	encode 'tiny' "crop=$((1920/2)):$((1080/2)):200:$((1080/2))" || exit $?
	post_test || exit $?
	play_encoded_files
	conditions="Playback, audio, subs, cropped"
	ask_if_ok "$conditions"
	return 0
}

 # This set requires you to put at the bottom of test_source_sets.sh
#  a line like uploader="$HOME/bin/uploader.sh" that would be sourced
#  from there. uploader.sh must be a script that uploads your files.
#
test_15_desc='Use both main codec combinations and test playback in the browser.'
test_15() {
	[ -x "$uploader" ] \
		|| err "Uploader “$uploader” is not an executable file."
	declare -gn source_set='anim_source_set2'
	prepare_test '15.a  Making a clip with WebM + VP9 + Opus and uploading it'
	encode 'tiny' || exit $?
	post_test || exit $?
	play_encoded_files
	info "Press any key to upload > "
	read -n1
	info 'Uploading…'
	"$uploader" "$new_file"

	prepare_test '15.b  Making a clip with MP4 + H264 + AAC and uploading it'
	change_in_rc 'ffmpeg_vcodec' 'libx264'
	change_in_rc 'ffmpeg_acodec' 'libfdk_aac'
	encode 'tiny' || exit $?
	post_test || exit $?
	play_encoded_files
	info "Press any key to upload > "
	read -n1
	info 'Uploading…'
	"$uploader" "$new_file"

	info "Both files should be uploaded by now. Please watch them
	      and then press any key to continue > "
	read -n1
	conditions="Both files, webm and mp4, are playing in the browser"
	ask_if_ok "$conditions"
	return 0
}

test_80_desc='With and without row_mt'
test_80() {
	declare -gn source_set='yurucamp_op_20s'
	prepare_test '80.a  ROW-MT: off'
	change_in_rc 'time_stat' 't'
	encode 'small' || exit $?
	post_test

	prepare_test '80.b  ROW-MT: on'
	change_in_rc 'time_stat' 't'
	change_in_rc 'libvpx_row_mt' '1'
	encode 'small' || exit $?

	echo
	info "Encode complete. Press any key to continue > "
	read -n1
	conditions="Videos created, decide which is better and encoded faster."
	ask_if_ok "$conditions"
	return 0
}



 # Test skeleton
#  (The test № 99 is never shown in the list and cannot be executed)
#
test_99_desc='What this test is made for'  # Will be shown in the main menu.
test_99() {
	declare -gn source_set='name_of_a_source_set (see above)'
	#  Copies exmaple.nadeshiko.rc.sh in place of RC file
	#  Checks, that source video is present.
	#  Shows a message “* Running test 99”
	prepare_test
	#  Alternate where the $new_file should be placed, if needed.
	#  By default it will be placed in $tests_dir, which is set to
	#  “$MYDIR/TESTS/<current_nadeshiko_version>/”
	where_to_place_new_file="$HOME"
	#  Change default settings in the RC file here, if needed.
	#  The parameter will be uncommented, if needed.
	change_in_rc 'parameter name' 'new value'
	#  This line calls Nadeshiko. Parameters, that tell which source video
	#  to use, Time1, Time2 and where to place the file are already there.
	encode 'tiny' || exit $?  # You probably want to quit on errors here.
	#  Get the name of the last encoded file and check if it exists.
	#  It will return >0, if there’d be no file! Use “||:” to avoid quitting,
	#  if bad exit is intended.
	post_test
	#  Play the file, if things cannot be done automatically.
	play_encoded_files
	#  Do autiomated checks. The format is $fileNN_parameter_name,
	#  see lib/gather_file_info for the list of available parameters.
	[ "$file99_vcodec" != VP9 ] \
		&& warn "Video codec is $file99_vcodec, should be VP9!"
	#  Do other stuff with the $new_file, analyze, read logs etc.
	cp "$where_to_place_new_file/$new_file" "$tests_dir"
	#  This shows the tester, what he should be looking for.
	#  Would be handy to show it before the test, too…
	conditions="Playback, 720p, audio"
	ask_if_ok "$conditions"
	return 0
}



pick_a_test() {
	local all_tests desc result
	until [ "$CHOSEN" = Quit ]; do
		all_tests=(  $(compgen -A function | grep -E '^test_[0-9]+$')  )
		# Unset the test-skeleton №99
		unset all_tests[$((${#all_tests[@]}-1))]
		for ((i=0; i<${#all_tests[@]}; i++)); do
			unset -n desc result
			declare -n desc="${all_tests[i]}_desc"
			declare -p ${all_tests[i]}_result &>/dev/null && {
				declare -n result=${all_tests[i]}_result
				case "$result" in
					OK)  result=" ${__bri}– OK –${__s}";;
					Fail)  result=" ${__bri}${__r}– Fail –${__s}";;
				esac
			}
			all_tests[$i]="${all_tests[i]#test_}${result:-}  ${desc:-}"
		done

		menu-list "Pick a test" "${all_tests[@]}" "Quit"
		[[ "$CHOSEN" =~ ^([0-9]+)\ .*$ ]] && {
			test_${BASH_REMATCH[1]} || err 'Error during the test execution.'
		}
	done
	return 0
}

pick_a_test

exit 0