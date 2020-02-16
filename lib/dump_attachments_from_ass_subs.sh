#  Should be sourced.

#  dump_attachments_from_ass_subs.sh
#  Library functions to decode and dump attachments from ASS subtitles.
#  © deterenkelt 2020
#
#  For licence see nadeshiko.sh


#  This library exists, because the “ass” subtitle filter in FFmpeg
#  cannot use fonts compiled in the .ass files themselves.


 # Takes a file which path is passed as $1 and decodes the uuencoded data
#  inside. Then dumps the decoded contents of the file to a directory speci-
#  fied in the environment variable ASS_DECODE_ATT_DESTDIR.
#
#  $1 – path to a file with uuencoded data, representing the contents of that
#       file. The name is expected to start with “uuenc.” and the rest would
#       be the desired file name for the decoded attachment.
#
ass_decode_file() {
	local  uuenc_data="$(< "$1")"
	local  dest_path
	local  dec_byte
	local  buf=''
	local  dword=()
	local  bytes=0
	local  i
	local  hex_numbers=( 0 1 2 3 4 5 6 7 8 9 a b c d e f )

	dest_path="${1##*/}"
	dest_path="${dest_path#uuenc.}"
	dest_path="$ASS_DECODE_ATT_DESTDIR/$dest_path"
	[[ "$dest_path" =~ \.[Tt][Tt][Ff]$ ]] || dest_path+='.ttf'


	info "File: “${dest_path##*/}”"
	milinc

	while read -r -n8; do
		dword=()
		bytes=0
		dword[0]=${REPLY:0:2}
		dword[1]=${REPLY:2:2}
		dword[2]=${REPLY:4:2}
		dword[3]=${REPLY:6:2}
		for i in {0..3}; do
			[ "${dword[i]}" ] && {
				[[ "${dword[i]}" =~ ^[0-9a-f]{2}$ ]]  || {
					warn "Weird byte “${dword[i]}”, expected 21…FF (hex)!
					      Cannot continue."
					return 0  # non-fatal for Nadeshiko.
				}
				(( 16#${dword[i]} < 33 )) && {
					warn "Weird byte “${dword[i]}” (hex) is less than 0x21 (decimal 33)!
					      Cannot continue."
					return 0  # non-fatal for Nadeshiko.
				}
				dword[i]=$(( 16#${dword[i]} - 33 ))  # result will be in decimal!
				let ++bytes
			}
		done

		(( bytes > 1 )) && {
			dec_byte=$(( (dword[0] << 2)  |  (dword[1] >> 4) ))
			buf+="\x${hex_numbers[ dec_byte/16 ]}${hex_numbers[ dec_byte % 16 ]}"
		}
		(( bytes > 2 )) && {
			dec_byte=$(( ((dword[1] & 0xF) << 4)  |  (dword[2] >> 2) ))
			buf+="\x${hex_numbers[ dec_byte/16 ]}${hex_numbers[ dec_byte % 16 ]}"
		}
		(( bytes > 3 )) && {
			dec_byte=$(( ((dword[2] & 0x3) << 6)  |  dword[3] ))
			buf+="\x${hex_numbers[ dec_byte/16 ]}${hex_numbers[ dec_byte % 16 ]}"
		}

	done < <( tr -d '[:space:]' <<<"$uuenc_data"  \
	              | od --address-radix=none --output-duplicates -t x1  \
	              | tr -d '[:space:]'
	        )

	 # Hopefully, using shell builtin here lifts the restriction on the length
	#  of the command line, i.e. ARG_MAX. There is, however, a restriction on
	#  the size of one argument, MAX_ARG_STRLEN. Fonts in under 2 MiB should
	#  be fine either way.
	#
	printf "$buf"  >"$dest_path"

	info "Extracted."
	mildec
	return 0
}


ass_dump_attachments() {
	ass_dump_fonts "$@"
	ass_dump_images "$@"
	return 0
}
ass_dump_fonts()  { __ass_dump_attachments "$@"; }
ass_dump_images() { __ass_dump_attachments "$@"; }
#
#  Finds attachments in an .ass file and dumps them to a directory.
#   $1  – path to an .ass file
#  [$2] – directory to where the extracted attachments should be placed.
#         if not specified, current directory would be used.
#
__ass_dump_attachments() {
	local  subtitle_path="$1"
	local  destination_path="${2:-./}"
	local  file_start_marker
	local  file_name
	local  reading_data
	local  uuenc_files=()
	local  uuenc_file
	local  i

	info "Extracting attachments from an .ass subtitle file
	      $subtitle_path"
	milinc

	[ "$destination_path" = './' ]  \
		&& info "Destination directory is not set. Will use current path:
		         $PWD"

	case "${FUNCNAME[1]}" in
		ass_dump_fonts)
			file_start_marker='fontname'
			;;
		ass_dump_images)
			file_start_marker='filename'
			;;
	esac

	while read -r; do
		#  If we’re in the [Fonts] or [Graphics] section
		[[ "$REPLY" =~ ^$file_start_marker ]] && {
			reading_data=t
			[[ "${uuenc_file:-}" != '' ]] && {
				echo "$uuenc_file"  >"${TMPDIR:-/tmp}/uuenc.$file_name"
				uuenc_files+=( "${TMPDIR:-/tmp}/uuenc.$file_name" )
				uuenc_file=''
			}
			file_name="${REPLY#$file_start_marker: }"
			file_name="${file_name##*/}"   #  Remove leading path, if present.
			file_name="${file_name##*\\}"  #  …also in case of a Windows path.
			file_name="${file_name%%$'\r'}"  #  …also in case of a Windows path.
			continue
		}

		[[ -v reading_data ]] && {
			#
			#  Stop reading uuencoded lines, if another section, e.g. [Graphics] starts.
			#  Thanks to the SSAv4+ specification, we know that lowercase characters
			#  cannot appear in the uuencoded data (due to the offset of 33).
			#
			[[ "$REPLY" =~ [a-z] ]] && break
			uuenc_file+="$REPLY"
		}
	done < "$subtitle_path"

	#  Add the last file.
	[[ "${uuenc_file:-}" != '' ]]  && {
		echo "$uuenc_file"  >"${TMPDIR:-/tmp}/uuenc.$file_name"
		uuenc_files+=( "${TMPDIR:-/tmp}/uuenc.$file_name" )
	}

	if (( ${#uuenc_files[*]} > 0 )); then
		info "Found ${#uuenc_files[*]} ${FUNCNAME[1]#ass_dump_}."
		info "Extraction path is “$destination_path”."
		#  Temporarily disabling trap on debug, for it will slow down
		#  our byte by byte reading.
		set +T
		export ASS_DECODE_ATT_DESTDIR="$destination_path"
		export TMPDIR

		if [ "$(type -t parallel)" = 'file' ]; then
			export -f ass_decode_file
			parallel --eta  ass_decode_file  ::: "${uuenc_files[@]}"
		else
			warn '“parallel” wasn’t found on this system.
			      Single-threaded extraction may take several minutes.'
			for uuenc_file in "${uuenc_files[@]}"; do
				ass_decode_file "$uuenc_file"
			done
		fi
		set -T
	else
		info 'No attachments found.'
	fi
	mildec

	return 0
}


return 0



                        #  Notes to developers  #

 # There was two primary sources of information:
#   - http://www.perlfu.co.uk/projects/asa/ass-specs.doc
#   - Aegisub source code, this file in particular:
#     aegisub-3.2.2/libaegisub/include/libaegisub/ass/uuencode.h
#
#  ASS subtitles use /a form/ of uuencoding, that means you can’t use
#  programs as “base64” or “uudecode”. I tried.
#
#  In short, to decode you take bytes in groups of 4, subtract 33 from each
#  byte and remove the compaction by bitwise shifts, so in the end it takes
#  only 3 bytes.
#
#  When bytes in numerical form are processed, the result is passed again
#  /as text/ to the outer printf, but with a backslash, hence the outer
#  printf sees that the shell passes it an octal digit \nnn. Bash varaibles
#  cannot store the null byte ($'\0'), since it’s the string end delimiter,
#  so the converted data must be passes byte by byte to a file.
#
#  By any means avoid subshell calls in  ass_decode_file(). They slow down
#  the decode. Changing subshell calls to function calls reduced execution time
#  from 43…47 sec to 7…8 sec for a 50 KiB file. Avoiding function calls saved
#  1 more second. Attachments can be megabytes.
#
#  “od” by default shortens the duplicate lines in the output and puts
#  an asterisk “*” in their place. To avoid that, “--output-duplicates”
#  is used.
#
#  Why not pass uuencoded data as an argument to ass_decode_file()? Because
#  it may cause problems if the file would take >2MiB (or >1.3 MiB on some old
#  systems). Remember, that uuencoded files are also 1/4 bigger. The main rea-
#  son to use named files is because there was a test case with real world
#  .ass file that had 4 embedded fonts, and passing them all uuencoded as
#  arguments to  “parallel ass_decode_file ::: …”  created a string too long
#  for the shell to run.
#
#  For whoever interested, whether this library can be used standalone, it
#  pretty much can, if you do these things:
#  - replace the first line with “#! /usr/bin/env bash”
#  - place “set -feu” before the function code starts
#  - replace “info” and “warn” functions with “echo”
#  - remove “milinc” and “mildec”
#  - convey the script args to the desired function with something like
#
#        ass_dump_attachments "$@"
#        exit 0
#
#    at the bottom of this file.
#