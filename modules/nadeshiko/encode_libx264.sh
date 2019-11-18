#  Should be sourced.

#  encode_libx264.sh
#  Nadeshiko encoding module for libx264.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh

#  Modules in Nadeshiko wiki:
#  https://github.com/deterenkelt/Nadeshiko/wiki/Writing-custom-modules


encode-libx264() {

	pass() {
		local pass=$1
		local pass1_params=( -pass 1 -sn -an  -f $ffmpeg_muxer  /dev/null )
		local pass2_params=( -pass 2 -sn ${audio_opts[@]}
		                     -movflags +faststart  "$new_file_name" )
		local ffmpeg_caught_an_error
		local ffmpeg_all_options=()
		local -n extra_options=libx264_pass${pass}_extra_options
		local -n mandatory_options=pass${pass}_params

		info "PASS $pass"

		 # Sets ffmpeg_progress_log, so must be called before
		#  setting ffmpeg_all_options.
		#
		launch_a_progressbar_for_ffmpeg

		 # Do not use addition to this array! This syntax, i.e.
		#      arr+=( new_item )
		#  messes up the order of the elements. Use only assignment.
		#
		ffmpeg_all_options=(
			-y  -hide_banner  -v error  -nostdin
			"${ffmpeg_input_options[@]}"
			-ss "${start[ts]}"
			-to "${stop[ts]}"
			"${ffmpeg_input_files[@]}"
			"${ffmpeg_color_primaries[@]}"
			"${ffmpeg_color_trc[@]}"
			"${ffmpeg_colorspace[@]}"
			"${map_string[@]}"
			"${vf_string[@]}"
			-c:v $ffmpeg_vcodec -pix_fmt $libx264_pix_fmt
				-g $libx264_keyint
				-b:v $vbitrate
				${libx264_qcomp:+-qcomp $libx264_qcomp}
			-preset:v $libx264_preset -tune:v $libx264_tune
			-profile:v $libx264_profile -level $libx264_level
			"${extra_options[@]}"
			${ffmpeg_progressbar:+-progress "$ffmpeg_progress_log"}
			-map_metadata -1
			-map_chapters -1
			-metadata title="$video_title"
			-metadata comment="Converted with Nadeshiko v$version"
			"${mandatory_options[@]}"
		)

		FFREPORT=file=$LOGDIR/ffmpeg-pass$pass.log:level=32  \
		$ffmpeg "${ffmpeg_all_options[@]}"  \
			|| ffmpeg_caught_an_error=t

		stop_the_progressbar_for_ffmpeg
		[ -v ffmpeg_caught_an_error ]  \
			&& err "ffmpeg error on pass $pass."
		return 0
	}

	pass 1
	pass 2
	return 0
}


return 0