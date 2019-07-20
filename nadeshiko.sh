#! /usr/bin/env bash

#  nadeshiko.sh
#  A Linux tool to cut small videos with ffmpeg.
#  © deterenkelt 2018–2019

 # This program is free software; you can redistribute it and/or modify it
#    under the terms of the GNU General Public License as published
#    by the Free Software Foundation; either version 3 of the License,
#    or (at your option) any later version.
#  This program is distributed in the hope that it will be useful,
#    but without any warranty; without even the implied warranty
#    of merchantability or fitness for a particular purpose.
#    See the GNU General Public License for more details.


set -feEuT
shopt -s extglob
BAHELITE_CHERRYPICK_MODULES=(
	error_handling
	logging
	rcfile
	misc
)
mypath=$(dirname "$(realpath --logical "$0")")
case "$mypath" in
	'/usr/bin'|'/usr/local/bin')
		source "${mypath%/bin}/lib/nadeshiko/bahelite/bahelite.sh";;
	*)
		source "$mypath/lib/bahelite/bahelite.sh";;
esac
prepare_cachedir
start_logging
noglob_off
rm -f "$LOGDIR/"ffmpeg*     \
      "$LOGDIR/"variables   \
      "$LOGDIR/time_output"
noglob_on
set_libdir
#  For parsing ffprobe and mediainfo output into usable format.
. "$LIBDIR/gather_file_info.sh"
#  For manipulating timestamp forms.
. "$LIBDIR/time_functions.sh"
set_modulesdir
noglob_off
for module in "$MODULESDIR"/nadeshiko_*.sh ; do
	. "$module" || err "Couldn’t source module $module."
done
noglob_on

set_metaconfdir
set_defconfdir
prepare_confdir
place_examplerc 'nadeshiko.10_main.rc.sh'
declare -gr RCFILE_REQUIRE_SCRIPT_NAME_IN_RCFILE_NAME=t

declare -r version='2.9.12'
declare -r release_notes_url="http://github.com/deterenkelt/Nadeshiko/blob/master/RELEASE_NOTES"

 # Minimal libav libraries versions
#  1) row-mt appeared after ffmpeg-3.4.2
#  2) -t <duration> doesn’t always grant precise end time,
#     but -to <timestamp> stopped causing problems only after ffmpeg-4.0.0.
declare -r libavutil_minver='56'
declare -r libavcodec_minver='58'
declare -r libavformat_minver='58'



show_help() {
	cat <<-EOF
	Usage
	./nadeshiko.sh  [start_time] [stop_time] [<other options>] <source_video>

	The order of options is free.

	       source_video – Path to the source video file.
	         start_time – Time on which clip should start.
	          stop_time – Time on which it should end.
	                      Any time format is valid:
	                      11:23:45.670   =  11 h 23 min 45 s 670 ms
	                         23:45.1     =  23 min 45 s 100 ms
	                           125.340   =  2 min 5 s 340 ms
	                             5       =  5 s
	                      Padding zeroes aren’t required.

	           (no)subs – enable/disable burning subtitles into video,
	                      also called hardsubbing. The default is to burn.
	          (no)audio – use/throw away audio track.
	                      The default is to add.
	         si, k=1000 – when converting [kMG] suffixes, use SI units.
	                      (Use it, if uploading limit is set in MB, not MiB).
	          <height>p – force encoding to the bitres profile for this height.
	                      Requesting upscale will result in an error.
	     tiny | small | – override the default maximum file size ($max_size_default).
	 normal | unlimited   Values must be set in nadeshiko.rc.sh beforehand.
	                      Default presets are: normal=$max_size_normal, small=$max_size_small, tiny=$max_size_tiny.
	    vb<number>[kMG] – force encoding with this exact video bitrate.
	                      A suffix may be applied: vb300000, vb1200k, vb2M.
	      ab<number>[k] – force encoding with this exact audio bitrate.
	                      Example: ab128000, ab192k, ab88k.
	       crop=W:H:X:Y – crop video. Cannot be used together with scaling.
	           <folder> – place encoded file into <folder>.
	      <config name> – alternate config file to use.
	                      Must be a file in $CONFDIR
	                      The filename must end with “.rc.sh”
	 fname_pfx=<string> – A custom string to be added to the name of the
	                      encoded file. Will be put at the beginning.


	Option descriptions are shortened for convenience,
	see the full version in the wiki: https://git.io/fx8DV

	Post bugs here: https://github.com/deterenkelt/Nadeshiko/issues
	EOF
	exit 0
}


show_version() {
	cat <<-EOF
	nadeshiko.sh $version
	© deterenkelt 2018–2019.
	Licence: GNU GPL version 3  <http://gnu.org/licenses/gpl.html>
	This is free software: you are free to change and redistribute it.
	There is no warranty, to the extent permitted by law.
	EOF
	exit 0
}


on_exit() {
	rm -f  ffmpeg2pass-0.log  ffmpeg2pass-0.log.mbtree
	#  Turning the cursor visible again,
	#  in case an error happened before ffmpeg progressbar could restore it.
	[ -v ffmpeg_progressbar ]  \
	&& [ ! -v do_not_report_ffmpeg_progress_to_console ]  \
		&& tput cnorm
	return 0
}



#  Stage 1
set_rcfile_from_args "$@"
read_rcfile
post_read_rcfile

#  Stage 2
info "Nadeshiko v$version"
print_verbosity_level
parse_args "${NEW_ARGS[@]}"
#  Checking video first, for set_vars() will run scene complexity test.
check_basic_util_support
set_vars
check_encoder_support  video  \
                       ${audio:+audio}  \
                       ${subs:+subs}
check_misc_util_support  ${time_stat:+time_stat}  \
                         ${check_for_updates:+check_for_updates}  \
                         ${ffmpeg_progressbar:+ffmpeg_progressbar}
[ -v check_for_updates ] && check_for_new_release_on_github
display_settings
until [ -v size_fits ]; do
	#  Stage 3
	fit_bitrate_to_filesize
	#  Stage 4
	encode
	new_file_size_B=$(stat --printf %s "$new_file_name")
	(( new_file_size_B <= max_size_B ))  \
	    && size_fits=t  \
	    || on_size_overshoot
done
#  Nadeshiko-mpv relies on this message to find the encoded file.
info-ns "Encoded successfully."
new_file_name=${new_file_name//\$/\\\$}
info "${new_file_name##*/}"
[ -v time_stat ] && print_stats
which xclip &>/dev/null && {
	echo -n "$new_file_name" | xclip
	info 'Copied path to clipboard.'
}
# [ -v pedantic ] && comme_il_faut_check "$new_file_name"  # needs update

exit 0
