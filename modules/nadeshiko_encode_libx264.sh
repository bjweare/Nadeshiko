#  Should be sourced.

#  nadeshiko-encode-libx264.sh
#  Nadeshiko module for encoding with libx264.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh

 # Modules in Nadeshiko wiki:
#  https://github.com/deterenkelt/Nadeshiko/wiki/Writing-custom-modules


encode-libx264() {

	pass() {
		local pass=$1
		local pass1_params=( -pass 1 -sn -an  -f mp4  /dev/null )
		local pass2_params=( -pass 2 -sn $audio_opts
		                     -movflags +faststart  "$new_file_name" )
		declare -n ffmpeg_command_end=pass${pass}_params
		declare -n extra_options=libx264_pass${pass}_extra_options
		info "PASS $pass"
		FFREPORT=file=$LOGDIR/ffmpeg-pass$pass.log:level=32 \
		$ffmpeg -y \
		            -ss "${start[ts]}" \
		            -t  "${duration[total_s_ms]}" \
		        -i "$video" \
		        "${ffmpeg_color_primaries[@]}" \
		        "${ffmpeg_color_trc[@]}" \
		        "${ffmpeg_colorspace[@]}" \
		        "${vf_string[@]}" \
		        $map_string \
		        -c:v $ffmpeg_vcodec -pix_fmt $ffmpeg_pix_fmt \
		            -g $libx264_keyint \
		            -b:v $vbitrate_bits \
		            ${libx264_qcomp:+-qcomp $libx264_qcomp} \
		        -preset:v $libx264_preset -tune:v $libx264_tune \
		        -profile:v $libx264_profile -level $libx264_level \
		        "${extra_options[@]}" \
		        -metadata title="$video_title" \
		        -metadata comment="Converted with Nadeshiko v$version" \
		        "${ffmpeg_command_end[@]}" \
			|| err "ffmpeg error on pass $pass."
		return 0
	}

	pass 1
	pass 2
	return 0
}

return 0