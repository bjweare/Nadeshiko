#  Should be sourced.

#  nadeshiko-encode-libvpx-vp9.sh
#  Nadeshiko module for encoding with libvpx-vp9.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh

#  Modules in Nadeshiko wiki:
#  https://github.com/deterenkelt/Nadeshiko/wiki/Writing-custom-modules



log2() {
	local x=$1 n=2 l=-1
	while ((x)); do ((l+=1, x/=n, 1)); done
	echo $l
}


 # Calculate the optimal amount of -tile-columns and -threads.
#  Since -threads works as a cap, it is useful to cap the number
#  of threads to the point it is useful. For example, a 640×480 video
#  would make use only of two tile columns (1 or 2 threads per each).
#
calc_adaptive_tile_columns() {
	declare -g  libvpx_vp9_tile_columns  libvpx_vp9_threads
	local tile_column_min_width=256  scaled_width
	[ -v libvpx_vp9_adaptive_tile_columns ] && {
		if [ -v scale ]; then
			if [  -v src_v[resolution]  ]; then
				scaled_width=$(( src_v[width] * scale / src_v[height] /2*2 ))
				libvpx_vp9_tile_columns=$((    scaled_width
				                             / tile_column_min_width  ))
			else
				libvpx_vp9_tile_columns=1
			fi
		elif [ -v crop ]; then
			libvpx_vp9_tile_columns=$((    crop_w
			                             / tile_column_min_width  ))
		else
			#  Native resolution
			libvpx_vp9_tile_columns=$((    src_v[width]
			                             / tile_column_min_width  ))
		fi
		# Videos with a width smaller than $tile_column_min_width
		# as well as cropped ones will result in 0 tile-columns
		# and log2(0) will return -1, while it should still return 0,
		# because at least one tile-column must be present, as 2⁰ = 1.
		[ $libvpx_vp9_tile_columns -eq 0 ] && libvpx_vp9_tile_columns=1
		# tile-columns should be a log2(actual number of tile-columns)
		libvpx_vp9_tile_columns=$(log2 $libvpx_vp9_tile_columns)
		# if [ $libvpx_vp9_tile_columns -le 3 ]; then
			# For resolutions under 2160p docs on Google Devs advise to use
			# 2× threads as tile-columns.
			libvpx_vp9_threads=$(( 2**(libvpx_vp9_tile_columns+1)  ))
		# else
			# And for 2160p they somehow get 16 tile-columns,
			# with --tile-columns 4 (sic!), even though in this case –
			# the only such case – the width, which is 3840 px, cannot
			# accomodate 16×256 tile-columns. Considering this a mistake.
		# 	libvpx_vp9_threads=$((   2**libvpx_vp9_tile_columns
		# 	                       + 2**(libvpx_vp9_tile_columns-1)  ))
		# fi
	}
	return 0
}


set_quantiser_min_max() {
	declare -g  libvpx_vp9_min_q  libvpx_vp9_max_q
	if  [ ! -v libvpx_vp9_cq_level ]  \
		&& [ ! -v libvpx_vp9_min_q ]  \
		&& [ ! -v libvpx_vp9_max_q ]
	then
	  	#  If global (aka manual) overrides aren’t set, use the values
	  	#  from bitrate-resolution profile.
	  	[ "${bitres_profile[libvpx-vp9_min_q]:-}" ] \
			&& libvpx_vp9_min_q=${bitres_profile[libvpx-vp9_min_q]}
		[ "${bitres_profile[libvpx-vp9_max_q]:-}" ] \
			&& libvpx_vp9_max_q=${bitres_profile[libvpx-vp9_max_q]}
		#  Without setting -crf quality was slightly better.
		#  declare -n libvpx_vp9_cq_level=${bitres_profile[libvpx-vp9_min_q]}
	fi
	return 0
}


calc_vbr_range() {
	#  RC and vpxenc use percents, ffmpeg uses bitrate.
	minrate=$((  vbitrate*$libvpx_vp9_minsection_pct/100  ))
	maxrate=$((  vbitrate*$libvpx_vp9_maxsection_pct/100  ))
	return 0
}


libvpx18_check() {
	declare -g libvpx_vp9_auto_alt_ref

	#  1. Checking ffmpeg version
	if	compare_versions "$libavcodec_ver" '<' '58.39.100'  \
		&& (( libvpx_vp9_auto_alt_ref > 1 ))
	then
		warn 'Libavcodec version is lower than 58.39.100!
		      Dropping -auto-alt-ref to 1.'
		libvpx_vp9_auto_alt_ref=1
	fi

	#  2. Checking vpxenc version
	local vpxenc_version=$(
		vpxenc --help | sed -rn 's/.*WebM\sProject\sVP9\sEncoder\sv([0-9]+\.[0-9]+(\.[0-9]+|))\s.*/\1/p'
	)
	is_version_valid "$vpxenc_version" || {
		(( libvpx_vp9_auto_alt_ref != 0 )) && {
			warn 'Couldn’t determine libvpx version!
			      Setting -auto-alt-ref to 1 for safe encoding.'
			libvpx_vp9_auto_alt_ref=1
		}
		return 0
	}
	if	compare_versions "$vpxenc_version" '<' "1.8.0"  \
		&& (( libvpx_vp9_auto_alt_ref > 1 ))
	then
		warn 'Libvpx version is lower than 1.8.0!
		      Dropping -auto-alt-ref to 1.'
		libvpx_vp9_auto_alt_ref=1
	fi
	return 0
}


encode-libvpx-vp9() {
	local  minrate maxrate
	calc_adaptive_tile_columns
	set_quantiser_min_max
	calc_vbr_range
	libvpx18_check

	pass() {
		local pass=$1
		local pass1_params=( -pass 1 -sn -an -f $ffmpeg_muxer /dev/null )
		local pass2_params=( -pass 2 -sn ${audio_opts[@]} "$new_file_name" )
		local ffmpeg_caught_an_error
		declare -n ffmpeg_command_end=pass${pass}_params
		declare -n deadline=libvpx_vp9_pass${pass}_deadline
		declare -n cpu_used=libvpx_vp9_pass${pass}_cpu_used
		declare -n extra_options=libvpx_vp9_pass${pass}_extra_options
		info "PASS $pass"
		launch_a_progressbar_for_ffmpeg

		FFREPORT=file=$LOGDIR/ffmpeg-pass$pass.log:level=32  \
		$ffmpeg -y -v error  -nostdin  \
		            -ss "${start[ts]}"  \
		            -to "${stop[ts]}"  \
		        "${ffmpeg_input_options[@]}"  \
		        "${ffmpeg_input_files[@]}"  \
		        "${ffmpeg_color_primaries[@]}"  \
		        "${ffmpeg_color_trc[@]}"  \
		        "${ffmpeg_colorspace[@]}"  \
		        "${map_string[@]}"  \
		        "${vf_string[@]}"  \
		        ${libvpx_vp9_max_q:+-qmax $libvpx_vp9_max_q}  \
		        ${libvpx_vp9_min_q:+-qmin $libvpx_vp9_min_q}  \
		            ${libvpx_vp9_cq_level:+-crf $libvpx_vp9_cq_level}  \
		        -aq-mode $libvpx_vp9_aq_mode  \
		        -c:v $ffmpeg_vcodec  \
		            -pix_fmt $libvpx_vp9_pix_fmt  \
		            -b:v $vbitrate  \
		                -minrate $minrate  \
		                -maxrate $maxrate  \
		        -g $libvpx_vp9_kf_max_dist  \
		        -auto-alt-ref $libvpx_vp9_auto_alt_ref  \
		            -lag-in-frames $libvpx_vp9_lag_in_frames  \
		        -frame-parallel $libvpx_vp9_frame_parallel  \
		        -tile-columns $libvpx_vp9_tile_columns  \
		        -threads $libvpx_vp9_threads  \
		        -row-mt $libvpx_vp9_row_mt  \
		        ${libvpx_vp9_bias_pct:+-qcomp $libvpx_vp9_bias_pct}  \
		            -overshoot-pct $libvpx_vp9_overshoot_pct  \
		            -undershoot-pct $libvpx_vp9_undershoot_pct  \
		        -deadline $deadline  \
		            -cpu-used $cpu_used  \
		        -tune-content $libvpx_vp9_tune_content  \
		        ${libvpx_vp9_tune:+-tune $libvpx_vp9_tune}  \
		        "${extra_options[@]}"  \
		        ${ffmpeg_progressbar:+-progress "$ffmpeg_progress_log"}  \
		        -map_metadata -1  -map_chapters -1  \
		        -metadata title="$video_title"  \
		        -metadata comment="Converted with Nadeshiko v$version"  \
		        "${ffmpeg_command_end[@]}"  \
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
