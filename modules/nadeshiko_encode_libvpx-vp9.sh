#  Should be sourced.

#  nadeshiko-encode-libvpx-vp9.sh
#  Nadeshiko module for encoding with libvpx-vp9.
#  deterenkelt © 2018
#
#  For licence see nadeshiko.sh

 # Modules in Nadeshiko wiki:
#  https://github.com/deterenkelt/Nadeshiko/wiki/Writing-custom-modules


 # Pseudo-boolean config option, that should be unset after reading
#  the RC file, if it’s set to a negative value.
#
RCFILE_BOOLEAN_VARS+=( libvpx_adaptive_tile_columns )


encode-libvpx-vp9() {
	local encoding_res tile_column_min_width=256 minrate maxrate
	log2() {
		local x=$1 n=2 l=-1
		while ((x)); do ((l+=1, x/=n, 1)); done
		echo $l
	}
	#  Since -threads works as a cap, it is useful to cap the number
	#  of threads to the point it is useful. For example, a 640×480 video
	#  would make use only of two tile columns (1 or 2 threads per each).
	[ -v libvpx_adaptive_tile_columns ] && {
		if [ -v scale ]; then
			encoding_res=$scale
			if [ -v have_orig_res ]; then
				scaled_width=$(( orig_width * scale / orig_height /2 *2 ))
				libvpx_tile_columns=$((    scaled_width
				                         / tile_column_min_width  ))
			else
				libvpx_tile_columns=1
			fi
		elif [ -v crop ]; then
			libvpx_tile_columns=$((    crop_w
			                         / tile_column_min_width  ))
		else
			#  Native resolution
			libvpx_tile_columns=$((    orig_width
			                         / tile_column_min_width  ))
		fi
		# Videos with a width smaller than $tile_column_min_width
		# as well as cropped ones will result in 0 tile-columns
		# and log2(0) will return -1, while it should still return 0,
		# because at least one tile-column must be present, as 2⁰ = 1.
		[ $libvpx_tile_columns -eq 0 ] && libvpx_tile_columns=1
		# tile-columns should be a log2(actual number of tile-columns)
		libvpx_tile_columns=$(log2 $libvpx_tile_columns)
		# if [ $libvpx_tile_columns -le 3 ]; then
			# For resolutions under 2160p docs on Google Devs advise to use
			# 2× threads as tile-columns.
			libvpx_threads=$(( 2**(libvpx_tile_columns+1)  ))
		# else
			# And for 2160p they somehow get 16 tile-columns,
			# with --tile-columns 4 (sic!), even though in this case –
			# the only such case – the width, which is 3840 px, cannot
			# accomodate 16×256 tile-columns. Considering this a mistake.
		# 	libvpx_threads=$((   2**libvpx_tile_columns
		# 	                   + 2**(libvpx_tile_columns-1)  ))
		# fi
	}

	if  [ ! -v libvpx_cq_level ]  \
		&& [ ! -v libvpx_min_q ]  \
		&& [ ! -v libvpx_max_q ]
	then
	  	#  If global (aka manual) overrides aren’t set, use the values
	  	#  from bitrate-resolution profile.
	  	[ "${bitres_profile[libvpx-vp9_min_q]:-}" ] \
			&& declare -g libvpx_min_q=${bitres_profile[libvpx-vp9_min_q]}
		[ "${bitres_profile[libvpx-vp9_max_q]:-}" ] \
			&& declare -g libvpx_max_q=${bitres_profile[libvpx-vp9_max_q]}
		#  Without setting -crf quality was slightly better.
		#  declare -n libvpx_cq_level=${bitres_profile[libvpx-vp9_min_q]}
	fi

	#  RC and vpxenc use percents, ffmpeg uses bitrate.
	minrate=$((  vbitrate_bits*$libvpx_minsection_pct/100  ))
	maxrate=$((  vbitrate_bits*$libvpx_maxsection_pct/100  ))

	pass() {
		local pass=$1 \
		      pass1_params=( -pass 1 -sn -an -f webm /dev/null ) \
		      pass2_params=( -pass 2 -sn $audio_opts "$new_file_name" )
		declare -n ffmpeg_command_end=pass${pass}_params
		declare -n deadline=libvpx_pass${pass}_deadline
		declare -n cpu_used=libvpx_pass${pass}_cpu_used
		declare -n extra_options=libvpx_pass${pass}_extra_options
		info "PASS $pass"
		FFREPORT=file=$LOGDIR/ffmpeg-pass$pass.log:level=32 \
		$ffmpeg -y \
		            -ss "${start[ts]}" \
		            -t  "${duration[total_s_ms]}" \
		        -i "$video" \
		        "${ffmpeg_color_primaries[@]}" \
		        "${ffmpeg_color_trc[@]}" \
		        "${ffmpeg_colorspace[@]}" \
		        ${vf_string:-} \
		        $map_string \
		        ${libvpx_max_q:+-qmax $libvpx_max_q} \
		        ${libvpx_min_q:+-qmin $libvpx_min_q} \
		            ${libvpx_cq_level:+-crf $libvpx_cq_level} \
		        -aq-mode $libvpx_aq_mode \
		        -c:v $ffmpeg_vcodec -pix_fmt $ffmpeg_pix_fmt \
		            -b:v $vbitrate_bits \
		                -minrate $minrate \
		                -maxrate $maxrate \
		        -g $libvpx_kf_max_dist \
		        -auto-alt-ref $libvpx_auto_alt_ref \
		            -lag-in-frames $libvpx_lag_in_frames \
		        -frame-parallel $libvpx_frame_parallel \
		        -tile-columns $libvpx_tile_columns \
		        -threads $libvpx_threads \
		        -row-mt $libvpx_row_mt \
		        ${libvpx_bias_pct:+-qcomp $libvpx_bias_pct} \
		            -overshoot-pct $libvpx_overshoot_pct \
		            -undershoot-pct $libvpx_undershoot_pct \
		        -deadline $deadline \
		            -cpu-used $cpu_used \
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