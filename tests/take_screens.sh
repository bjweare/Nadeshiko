#!/bin/bash

set -feEu #T

. "$(dirname "$0")/../lib/bahelite/bahelite.sh"

# Wiki:
# https://github.com/deterenkelt/Nadeshiko/wiki/Docs-on-encoding.-Filters#taking-screenshots-ssim

show_help() {
	cat <<-EOF
	Usage:
	./take_screens.sh  -f <FILE>  -o <jpg|png>  [OPTIONS]  <T1>  [T2  [… Tn]]

	-f,--file <FILE> – path to a video file.
	-o,--output-format <jpg|png> – output image format.
	-t,--text <TEXT> – a string to print over the image. May be a pattern.
	    An empty string “” uses default pattern “%filename%r%timestamp”.
	    “-” disables text.
	    In the pattern three keywords are recognised:
	    - %filename – source file name, directories removed.
	    - %timestamp – current timestamp (T1, T2…) in “HH:MM:SS.ms” format.
	    - %r – a newline.
	-g,--gravity <n|s|w|e|c|ne|nw|se|sw> – side to which place TEXT.
	--ss,--skip-to-time <SECONDS[.milliseconds]> – if set, this time
	    is added to each of the T1, T2 … Tn. It’s useful, if you took
	    timestamps from short clips, but need to take frames
	    from the original video, that was the source for them.
	    Actually useless, because encoded clip will have its own
	    timestamps, slightly differing from the source. To take precise
	    screenshots from the source file, the timestamps must be found
	    with an eye and passed as T1, T2 … Tn (without --ss).
	--font <FONT FAMILY NAME> – use system font to print TEXT over image.
	--font-file <PATH TO FILE> – use the font from this file.
	--font-size <NUMBER> – point size to use.
	--leading <NUMBER> – space between lines, in points
	    (for regular fonts 1/2 of font-size is good).
	--box-padding <NUMBER> – how much pixels (or points?) should be
	     between TEXT and the border of its box.
	--screen-padding <NUMBER> – how far from the screen the box with TEXT
	     should stand. Screen padding is calculated as FRAME_WIDTH/NUMBER,
	     i.e. if --gravity set to NW (top left) and --screen-padding is 25,
	     then the box with TEXT will stand out from the top left corner
	     on 1/25 of the total frame width and 1/25 of the total frame height.

	T1, T2 … Tn – timestamps in the format seconds.milliseconds: “0”, “5.5”,
	    “1278.654” to point ffmpeg at them and take a frame as an image
	    of FORMAT type.

	EOF
}


parse_args() {
	opts=$(getopt  --options  f:o:t:g:h \
	               --longoptions \
file:,\
output-format:,\
text:,\
gravity:,\
help,\
ss:,skip-to-time:,\
font:,\
font-file:,\
font-size:,\
leading:,\
box-padding:,\
screen-padding: \
	               -n 'take_screens.sh' -- "$@") \
		|| err 'Error while parsing options'
	eval set -- "$opts"

	while true; do
		case "$1" in
			-f|'--file')
				video="$2"
				shift 2
				;;
			-o|'--output-format')
				format="$2"
				shift 2
				;;
			-t|'--text')
				draw_text="$2"
				shift 2
				;;
			-g|'--gravity')
				gravity="$2"
				shift 2
				;;
			-h|'--help')
				show_help
				exit 0
				;;
			'--ss'|'--skip-to-time')
				# no -s option, because -ss (with one dash) mistakingly
				# typed after ffmpeg’s key would be recognised
				# as two “-s -s” options.
				skip_time="$2"
				shift 2
				;;
			'--font')
				font="$2"
				shift 2
				;;
			'--font-file')
				font_file="$2"
				shift 2
				;;
			'--font-size')
				font_size="$2"
				shift 2
				;;
			'--leading')
				leading="$2"
				shift 2
				;;
			'--box-padding')
				box_padding="$2"
				shift 2
				;;
			'--screen-padding')
				screen_padding="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
			*)
				err "Unknown option “$option”."
				;;
		esac
	done
	timestamps=($*)
	return 0
}


 # Extracts frames from a video file at given timestamps.
#
take_screens() {
	local timestamp out_file c vf_drawtext x y  dt_pat  ts_fn  fn_ts \
	      sp=${screen_padding:-25}
	out_file="${video##*/}"
	out_file="${out_file%.*}"
	# set -x
	fn_ts='%filename%r%timestamp'
	ts_fn='%timestamp%r%filename'
	dt_pat="$ts_fn"  # timestamp – top, filename – bottom
	case "${gravity:-s}" in
		n)  x="(w-text_w)/2"      y="(h/$sp)"           dt_pat="$fn_ts";;
		w)  x="(w/$sp)"           y="(h-text_h)/2"      ;;
		s)  x="(w-text_w)/2"      y="(h-h/$sp-text_h)"  ;;
		e)  x="(w-w/$sp-text_w)"  y="(h-text_h)/2"      ;;
		ne) x="(w-w/$sp-text_w)"  y="(h/$sp)"           dt_pat="$fn_ts";;
		nw) x="(w/$sp)"           y="(h/$sp)"           dt_pat="$fn_ts";;
		se) x="(w-w/$sp-text_w)"  y="(h-h/$sp-text_h)"  ;;
		sw) x="(w/$sp)"           y="(h-h/$sp-text_h)"  ;;
		c)  x='(w-text_w)/2'      y='(h-text_h)/2'      ;;
	esac

	case "${draw_text:-}" in
		'-')
			draw_text=''
			;;
		'')
			draw_text="$dt_pat"
			;;
		*)
			# Here must be some transposition of filename and timestamp
			# in the user’s pattern.
			dt_pat="$draw_text"
			:;;
	esac

	c=0
	# draw_text='ORRRRRRRRRRRRRRRA'
	for timestamp in "${timestamps[@]}"; do
		[ "${skip_time:-}" ] && timestamp=$(
			echo "scale=3; $timestamp+$skip_time" | bc)
		[ "$draw_text" ] && {
			draw_text="$dt_pat"
			draw_text=${draw_text//%filename/${video##*/}}
			draw_text=${draw_text//%timestamp/%\{pts:hms:$timestamp\}}
			# $'\r', because $vf_drawtext will break with $'\n'.
			# And no, just \n or \r won’t do: ffmpeg will print them
			# as strings, however many backslashes you put before them.
			draw_text="${draw_text//%r/$'\r'}"
			# draw_text=${draw_text//\:/\\\:}
			if [ -v font ]; then
				font_opt="font='$font':"
			elif [ -v font_file ]; then
				font_file_opt="fontfile='$font_file':"
			else
				font_opt="font='${font:-Sans}':"
			fi
			# ⋅ setpts=PTS-STARTPTS – to guarantee, that the timestamp
			#   in %{pts:hms:$timestamp} will be aligned to 00:00:00.000
			#   (deviations like 00:00:00.008 were spotted).
			# ⋅ The colon escape works right only inside the expression.
			#   free_shrugs.jpg
			vf_drawtext=(-vf "setpts=PTS-STARTPTS,drawtext=\
				${font_opt:-}${font_file_opt:-} \
				text='${draw_text//:/\\\:}': \
				fontcolor=white: \
				fontsize=${font_size:-24}: \
				line_spacing=${leading:-12}: \
				box=1: \
				boxcolor=black@0.5: \
				boxborderw=${box_padding:-15}: \
				x=$x: \
				y=$y  "
			)
		}
		FFREPORT=file=ffmpeg-take-screens.log:level=32 \
		ffmpeg -hide_banner -y -ss "$timestamp" -i "$video" \
		       -frames:v 1  -vsync vfr  "${vf_drawtext[@]}"  \
		       "${out_file}_$(printf '%04d' $c).$format"
		[ $? -eq 0 ] && rm ffmpeg-take-screens.log
		((c++, 1))
	done


	return 0
	# case "$type" in
	# 	tile-hor) tiling=",tile=${#}x1"  frames=1  out_file+=".$format";;
	# 	tile-vert) tiling=",tile=1x${#}"  frames=1  out_file+=".$format";;
	# 	separated) frames=$#  out_file+="_%04d.$format";;
	# esac

	# on timestamps higher than 100 error: “muxing overhead: unknown”
	# ffmpeg -hide_banner -y -i "$video" \
	#        -frames:v $frames \
	#        -filter:v "select='$timestamps'${tiling:-},setpts='N/(25*TB)',setpts=PTS-STARTPTS" \
	#        -vsync vfr \
	#        "$out_file"
	# return 0
}

parse_args "$@"
take_screens