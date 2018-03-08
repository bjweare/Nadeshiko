#! /usr/bin/env bash

# nadeshiko_tests.sh
#   Test to see check how parameters applied and to ensure,
#   that the resulting file is what it should be.
#   deterenkelt © 2018

# WTFPL

set -feE
. "$(dirname "$0")/../bhlls.sh"
. "$(dirname "$0")/../gather_file_info.sh"


 # Below are 20-something tests grouped into 5 sets.
#  Certain tests require specific input data, such as having subtitles
#  and displaying them (there should be lines on the screen) on the time
#  Nadeshiko should cut.

[ -r "$MYDIR/files_for_sets" ] || {
	cat <<-EOF >&2
	$0 uses $MYDIR/files_for_sets to pick paths for test sets.
	One line – one file. Nth line corresponds to the Nth set.
	EOF
	err "Set source files first."
}

nadeshiko_dir="$MYDIR/.."
nadeshiko="$nadeshiko_dir/nadeshiko.sh"
rc_file="$nadeshiko_dir/nadeshiko.rc.sh"

# Backup RC file, put our test dummy.
[ -e "$rc_file" ] && {
	mv "$rc_file" "$rc_file.yuzyanoerusi.bak"
	moved_rc_file=t
	touch $rc_file
}
# And always return it back on exit
on_exit() {
	cd "$MYDIR"
	# But only if we actually moved it – don’t overwrite it by an accident.
	[ -v moved_rc_file ] && mv "$rc_file.yuzyanoerusi.bak" "$rc_file"
	return 0
}

# test_dir="tests_`date +%Y%m%d-%H%M%S`"
test_dir="$MYDIR/sets"
[ -d "$test_dir" ] || mkdir "$test_dir"
cd "$test_dir"


get_last_encoded_file() {
	local last_log last_file
	pushd "$nadeshiko_dir/nadeshiko_logs" >/dev/null
	last_log=$(ls -tr | tail -n1)
	[ -r "$last_log" ] || {
		warn "Cannot get last log."
		return 1
	}
	last_file=$(
		sed -rn '/Encoded successfully/,/Copied path to/ {
			                                                n
			                                                s/^.{11}//
			                                                s/.{4}$//p  }' \
		        "$last_log"
	)
	popd >/dev/null
	echo "$last_file"
	return 0
}

 # Set 1
#  - make a regular video; it should be short so that the resolution was
#    kept native;
#  - move the new file into a specified folder;
#  - test the default codecs: libx264 and aac;
#  - set the times as “0” and “5.00”, duration should be 5 seconds;
#  - file size shouldn’t exceed max_size_default.
#
#  $1 – path to source video.
#
set1() {
	local sfile="$1" file_ok plays_ok quality_ok sound_ok new_file
	info "Running ${FUNCNAME[0]}."
	[ -r "$sfile" ] || err "Source video not a readable file: “$sfile”."
	echo > "$rc_file"
	touch t
	$nadeshiko "$sfile" 0 5.00 "$HOME"
	new_file="$HOME/$(get_last_encoded_file)"
	# sfile "$new_file"
	[ -r "$new_file" ] && [ "$new_file" -nt ./t ] && file_ok=t || {
		warn "No file created."
		return 3
	}
	mpv "$new_file"
	menu "Video plays?"  Yes No
	[ "$CHOSEN" = Yes ] && plays_ok=t
	menu "Video quality is OK?"  Yes No
	[ "$CHOSEN" = Yes ] && quality_ok=t
	menu "Sound is hearable?"  Yes No
	[ "$CHOSEN" = Yes ] && sound_ok=t

	gather_file_info "$new_file" 1
	info "Vcodec: $file1_vcodec"
	info "Profile: $file1_vcodec_profile"
	info "Profile: $file1_acodec"
	info "Chroma: $file1_colourspace $file1_chroma"

	[ "$file1_duration_total_s" != '5' ] && {
		warn "Duration is $file1_duration_total_s, should be 5 s."
	}

	mv "$new_file" ./
	return 0
}

 # Set 2
#  - make a 3.5 min long file;
#  - “small” size (under 10M);
#  - “si” size (MB, not MiB);
#  - “nosub” – should have no subtitles;
#  - “noaudio” – should have no audio track
#
#  $1 – path to source video.
#
set2() {
	local sfile="$1" file_ok size_ok nosubs_ok noaudio_ok new_file_size
	info "Running ${FUNCNAME[0]}."
	[ -r "$sfile" ] || err "Source video not a readable file: “$sfile”."
	cat <<-EOF > $rc_file
	video_max_size_small=10M
	kilo=1000

	EOF

	touch t
	$nadeshiko "$sfile" 0 3:30 nosub noaudio small

	new_file="$(get_last_encoded_file)"
	# file "$new_file"
	[ -r "$new_file" ] && [ "$new_file" -nt ./t ] && file_ok=t || {
		warn "No file created."
		return 3
	}
	mpv "$new_file"
	menu "Video had subtitles?"  Yes No
	[ "$CHOSEN" = No ] && nosubs_ok=t
	menu "Video had sound?"  Yes No
	[ "$CHOSEN" = No ] && noaudio_ok=t

	new_file_size=$(stat --printf %s "$new_file")
	[ "$new_file_size" -le $((10*1000*1000)) ] \
		&& size_ok=t \
		|| warn "Size exceeded. Presently “$new_file_size”, should be <= 10 000 000."

	gather_file_info "$new_file" 1
	[ "$file1_duration_total_s" != $((3*60+30)) ] && {
		warn "Duration is $file1_duration_total_s, should be $((3*60+30)) s."
	}
	return 0
}

 # Set 3
#  - make a 1 sec video with high bitrate per second, but default size
#  - pass times in the wrong order
#  - “720p”
#  - “vb12M”
#  - “ab88k”
#  - libfdk_aac
#
#  $1 – path to source video.
#
set3() {
	local sfile="$1" file_ok size_ok scale_ok forced_vbr_ok forced_abr_ok
	info "Running ${FUNCNAME[0]}."
	[ -r "$sfile" ] || err "Source video not a readable file: “$sfile”."
	cat <<-EOF > $rc_file
	ffmpeg_acodec=libfdk_aac

	EOF
	touch t
	#       stop time --v                  v----start time  (should be OK)
	$nadeshiko "$sfile" 1 720p vb12M ab88k 0

	new_file="$(get_last_encoded_file)"
	# file "$new_file"
	[ -r "$new_file" ] && [ "$new_file" -nt ./t ] && file_ok=t || {
		warn "No file created."
		return 3
	}
	mpv "$new_file"
	menu "Video had subtitles?"  Yes No
	[ "$CHOSEN" = No ] && nosubs_ok=t
	menu "Video had sound?"  Yes No
	[ "$CHOSEN" = No ] && noaudio_ok=t

	new_file_size=$(stat --printf %s "$new_file")
	[ "$new_file_size" -le $((20*1000*1000)) ] \
		&& size_ok=t \
		|| warn "Size exceeded. Presently “$new_file_size”, should be <= 20 000 000."

	gather_file_info "$new_file" 1
	[ "$file1_duration_total_s" != 1 ] && {
		warn "Duration is $file1_duration_total_s, should be 1 s."
	}
	[ "$file1_vbitrate" != 12000 ] && {
		warn "Video bitrate is $file1_vbitrate, should be 12 000."
	}

	# Returns either 50 (aac) or 96 (libfdk_aac).
	# Looks like the libs round to a closest… border?
	[ "$file1_abitrate" != 88 ] && {
		warn "Audio bitrate is ${file1_abitrate}k, should be 88k."
	}

	return 0
}

 # Set 4
#  - pass incompatible arguments.
#  - pass invalid data in RC file.
#
#  $1 – path to source video.
#
set4() {
	local sfile="$1"
	[ -r "$sfile" ] || err "Source video not a readable file: “$sfile”."
	echo > "$rc_file"
	info "Running ${FUNCNAME[0]}."
	info "These tests check wrong parameters, so FAILING IS OK!"
	#              OK---v    v---mistake, should quit.
	$nadeshiko "$sfile"  10  0.00:00  && {
		warn "Should’ve quitted: invalid time delimeter: ."
	}
	read -n1 -p 'Press any key to continue > '

	#  Cannot be together   vvvvvvv vvvvvv
	$nadeshiko "$sfile" 0 10 noaudio ab100k && {
		warn "Should’ve quitted: “noaudio” and “ab100k” cannot be used together."
	}
	read -n1 -p 'Press any key to continue > '

	#  Cannot be together   vvvvvvv vvvvvv
	$nadeshiko "$sfile"  0 12 576p crop=$((1920/2)):120:200:$((1080/2)) && {
		warn "Should’ve quitted: “crop” and “NNNp” cannot be used together."
	}
	read -n1 -p 'Press any key to continue > '

	cat <<-EOF >"$rc_file"
	ffmpeg_vcodec=hurr
	ffmpeg_acodec=durr

	EOF
	$nadeshiko "$sfile" 0 10  && {
		warn "Should’ve quitted: non-existing codecs."
	}

	cat <<-EOF >"$rc_file"
	container=mp4
	ffmpeg_vcodec=libx264
	ffmpeg_acodec=libvorbis

	EOF
	$nadeshiko "$sfile" 0 10  && {
		warn "Should’ve quitted: incompatible set of container and codecs."
	}

	cat <<-EOF >"$rc_file"
	container=webm
	ffmpeg_vcodec=libx264
	ffmpeg_acodec=aac

	EOF
	$nadeshiko "$sfile" 0 10  && {
		warn "Should’ve quitted: incompatible set of container and codecs."
	}

	cat <<-EOF >"$rc_file"
	container=webm
	ffmpeg_vcodec=libtheora
	ffmpeg_acodec=libvorbis

	EOF
	$nadeshiko "$sfile" 0 10  && {
		warn "Should’ve quitted: incompatible set of container and codecs."
	}
	return 0
	return 0
}

 # Set 5
#  - make a video of “tiny” (2M) size.
#  - crop a part of the video
#
#  $1 – path to source video.
#
set5() {
	local sfile="$1"
	[ -r "$sfile" ] || err "Source video not a readable file: “$sfile”."
	info "Running ${FUNCNAME[0]}."
	echo > "$rc_file"
	touch t
	#                             # SW part with subtitles.
	$nadeshiko "$sfile"  0 12 tiny crop=$((1920/2)):$((1080/2)):200:$((1080/2))
	new_file="$(get_last_encoded_file)"
	[ -r "$new_file" ] && [ "$new_file" -nt ./t ] && file_ok=t || {
		warn "No file created."
		return 3
	}
	mpv --loop-file=yes "$new_file"
	return 0
}


 # Set 6
#  - cut a video from a file with 4:3 aspect ratio
#
#  $1 – path to source video.
#
set6() {
	local sfile="$1"
	[ -r "$sfile" ] || err "Source video not a readable file: “$sfile”."
	info "Running ${FUNCNAME[0]}."
	ar=$(get_mediainfo_attribute "$sfile" v 'Display aspect ratio')
	[ "$ar" = '4:3' ] || {
		warn "A file with aspect ratio of 4:3 is needed for this set."
		return 3
	}
	echo > "$rc_file"
	touch t
	$nadeshiko "$sfile"  0 5
	new_file="$(get_last_encoded_file)"
	[ -r "$new_file" ] && [ "$new_file" -nt ./t ] && file_ok=t || {
		warn "No file created."
		return 3
	}

	#gather_file_info "$new_file" 1
	#res=$file1_height
	info 'Here you should check, that bitrate has underwent 4:3 correction.'
	return 0
}

 # Set 7
#  - make short videos with different combinations of A/V codecs.
#    You’re supposed to upload them somewhere, then see if browsers play it.
#
#  This set requires you to put at the bottom of files_for_tests.sh
#  a line like uploader="$HOME/bin/uploader.sh" that would be sourced
#  from there. uploader.sh must be a script that uploads your files.
#
set7() {
	local sfile="$1"
	[ -r "$sfile" ] || err "Source video not a readable file: “$sfile”."
	info "Running ${FUNCNAME[0]}."

	eval $(sed -n '$p' "$MYDIR/files_for_sets")

	 # mkv plays but it becomes 5 sec instead of specified 20
	#  and isn’t able to rewind.
	#
	# cat <<-EOF >"$rc_file"
	# container=mkv
	# ffmpeg_vcodec=libx264
	# ffmpeg_acodec=libopus

	# EOF
	# touch t
	# $nadeshiko "$sfile"  small  17:10  17:30
	# new_file="$(get_last_encoded_file)"
	# [ -r "$new_file" ] && [ "$new_file" -nt ./t ] && file_ok=t || {
	# 	warn "No file created."
	# 	return 3
	# }
	# $uploader "$new_file"

	cat <<-EOF >"$rc_file"
	container=webm
	ffmpeg_vcodec=libvpx-vp9
	ffmpeg_acodec=libopus

	EOF
	touch t
	$nadeshiko "$sfile"  small  17:11  17:31
	new_file="$(get_last_encoded_file)"
	[ -r "$new_file" ] && [ "$new_file" -nt ./t ] && file_ok=t || {
		warn "No file created."
		return 3
	}
	$uploader "$new_file"

	cat <<-EOF >"$rc_file"
	container=webm
	ffmpeg_vcodec=libvpx-vp9
	ffmpeg_acodec=libvorbis

	EOF
	touch t
	$nadeshiko "$sfile"  small  17:12  17:32
	new_file="$(get_last_encoded_file)"
	[ -r "$new_file" ] && [ "$new_file" -nt ./t ] && file_ok=t || {
		warn "No file created."
		return 3
	}
	$uploader "$new_file"
}

all_sets=$(compgen -A function | grep -E '^set[0-9]+$')

until [ "$CHOSEN" = Quit ]; do
	menu "Pick a set" $all_sets "Quit"
	if [[ "$CHOSEN" =~ ^set([0-9]+)$ ]]; then
		$CHOSEN "$(sed -n "${BASH_REMATCH[1]}p" "$MYDIR/files_for_sets")"
	fi
done

