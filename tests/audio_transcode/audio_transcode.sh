#! /usr/bin/env bash

#  audio_transcode.sh
#  Standalone testing script to see, how well each codec performs at using
#    specified bitrate (or quality settings, that in the end turn into lowering
#    bitrate), will it overshoot or undershoot and how much.
#  This script takes videos from several sources and encodes them to clips
#    of various duration with all audio codecs known to Nadeshiko, testing
#    all of their audio profiles, specified in Nadeshiko configuration, i.e.
#
#                      _ file 1
#                     /__ file 2
#                    /\___ file 3
#               _0:03
#              /
#             / _0:10 ⋅⋅⋅
#            /_/__0:30 ⋅⋅⋅
#        _48k ⋅⋅⋅
#       /
#      /___60k ⋅⋅⋅
#  Opus \_ ⋅⋅⋅
#
#
#  Vorbis ⋅⋅⋅
#
#  and dumps the results as a table into a CSV file.


set -feEu
shopt -s extglob


version='1.0'
mypath=$(dirname "$(realpath --logical "$0")")

. "$mypath/../../metaconf/nadeshiko.00_config_meta.rc.sh"
for file in $(set +f; ls -1 "$mypath/../../defconf/nadeshiko.90_*.rc.sh"); do
	. "$file"
done



report="$mypath/report_$(date +%F_%T).csv"
csv_header='Audio codec; Avg. bitrate; Duration, s; Audio source; Expected stream size, B; Stream size, B; 𝚫 stream size from the expected, in seconds of playback'
echo "$csv_header"  >"$report"

config="$mypath/config_$(date +%F_%T).sh"


#  Patema. BDrip, LC-AAC
#  Music, then speech. Sound effects.
#  (also this is a file without bitrate – good for testing Nadeshiko best audio algo.)
patema="$mypath/[Underwater] Patema Inverted - Sakasama no Patema (BD 1080p) [C8A27F7D].mkv"
# Format                                   : AAC
# Format/Info                              : Advanced Audio Codec
# Format profile                           : LC
# Codec ID                                 : A_AAC-2
# Duration                                 : 1 h 38 min
# Channel(s)                               : 6 channels
# Channel positions                        : Front: L C R, Side: L R, LFE
# Sampling rate                            : 48.0 kHz
# Frame rate                               : 46.875 FPS (1024 SPF)
# Compression mode                         : Lossy
# Title                                    : Japanese 5.1 AAC
# Language                                 : Japanese
# Default                                  : Yes
# Forced                                   : No


#  Love Lab EP 1. BDrip, FLAC (the only audio track)
#  Music (J-pop), then speech + light background music
lovelab="$mypath/[ReinForce] Love Lab - 01 (BDRip 1920x1080 x264 FLAC).mkv"
# Format                                   : FLAC
# Format/Info                              : Free Lossless Audio Codec
# Codec ID                                 : A_FLAC
# Duration                                 : 24 min 29 s
# Bit rate mode                            : Variable
# Channel(s)                               : 2 channels
# Channel positions                        : Front: L R
# Sampling rate                            : 48.0 kHz
# Bit depth                                : 16 bits
# Writing library                          : Lavf54.29.104
# Language                                 : Japanese
# Default                                  : Yes
# Forced                                   : No



#  Andrey Rublev. BluRay disk, PCM (3rd audio track = a:2)
#  Music, then ambient noises of different strength and voices
#  at different distances. Weak sounds, about which main character speaks.
rublev="$mypath/АНДРЕЙ РУБЛЁВ. Часть 1.m2ts"
# Format                                   : PCM
# Format settings                          : Big / Signed
# Muxing mode                              : Blu-ray
# Codec ID                                 : 128
# Duration                                 : 1 h 24 min
# Bit rate mode                            : Constant
# Bit rate                                 : 1 152 kb/s
# Encoded bit rate                         : 2 304 kb/s
# Channel(s)                               : 1 channel
# Channel positions                        : Front: C
# Sampling rate                            : 48.0 kHz
# Bit depth                                : 24 bits
# Stream size                              : 698 MiB (4%)

ffmpeg="ffmpeg -hide_banner -v error -nostdin -y"

acodecs=(
	libopus
	libvorbis
	libfdk_aac
	aac
	libmp3lame
	eac3
	ac3
	flac  #  Not for nadeshiko, but to compare the cut samples
	      #  with the original.
)

durations=(
	3
	10
	30
	60
	240
)


 # Floating point math precision.
#  Read the commentary for delta_for_config() to know the basis behind
#  this value.
#
bc_scale=4

 # bc returns numbers without a leading zero, i.e. -0.5  becomes -.5,
#  which is not convenient in the csv file. This function restores
#  the leading zero for the variable passed as first argument.
#  $1 – variable name, in which value the leading zero should be restored.
#
restore_zero() {
	local varname="$1"
	declare -n varval=$varname
	[ "${varval:0:1}" = '.' ] && varval="0$varval"
	[ "${varval:0:2}" = '-.' ] && varval="-0${varval#-}"
	return 0
}

calc_data() {
	rm -f /tmp/aud.raw || true
	mkvextract "$output_fname" tracks --fullraw 0:/tmp/aud.raw  &>/dev/null
	stream_size=$( stat -c %s /tmp/aud.raw )

	expected_stream_size=$(
		echo "scale=$bc_scale; $duration*$profile*1000/8" | bc
	)
	restore_zero 'expected_stream_size'

	delta_size_sec=$(
		echo "scale=$bc_scale; ($stream_size - $expected_stream_size) /($profile*1000)" | bc
	)
	restore_zero 'delta_size_sec'

	[ "$(echo "scale=$bc_scale; $delta_size_sec < $cur_duration_min" | bc)" = '1' ]  \
		&& cur_duration_min=$delta_size_sec \
		&& restore_zero 'cur_duration_min'
	[ "$(echo "scale=$bc_scale; $delta_size_sec > $cur_duration_max" | bc)" = '1' ]  \
		&& cur_duration_max=$delta_size_sec \
		&& restore_zero 'cur_duration_max'

	[ "$(echo "scale=$bc_scale; $delta_size_sec < $cur_profile_min" | bc)" = '1' ]  \
		&& cur_profile_min=$delta_size_sec \
		&& restore_zero 'cur_profile_min'
	[ "$(echo "scale=$bc_scale; $delta_size_sec > $cur_profile_max" | bc)" = '1' ]  \
		&& cur_profile_max=$delta_size_sec \
		&& restore_zero 'cur_profile_max'

	[ "$(echo "scale=$bc_scale; $delta_size_sec < $cur_acodec_abs_min" | bc)" = '1' ]  \
		&& cur_acodec_abs_min=$delta_size_sec \
		&& restore_zero 'cur_acodec_abs_min'
	[ "$(echo "scale=$bc_scale; $delta_size_sec > $cur_acodec_abs_max" | bc)" = '1' ]  \
		&& cur_acodec_abs_max=$delta_size_sec \
		&& restore_zero 'cur_acodec_abs_max'

	return 0
}

print_report_line() {
	#  Code word of the source file.
	local audio_source_code="$1"
	local signed_delta_size_sec=$delta_size_sec
	if [ "$(echo "scale=$bc_scale; $signed_delta_size_sec > 0" | bc)" = '1' ]; then
		signed_delta_size_sec="+$signed_delta_size_sec"
	elif [ "$(echo "scale=$bc_scale; $signed_delta_size_sec < 0" | bc)" = '1' ]; then
		#  Proper minus sign
		signed_delta_size_sec="${signed_delta_size_sec//-/−}"
	else
		# == 0
		# Strip .00
		signed_delta_size_sec='0'
	fi

	echo "$acodec;$profile k;$duration;$audio_source_code;$expected_stream_size;$stream_size;$signed_delta_size_sec s"  >>"$report"
	return 0
}

print_report_profile_min_max_delta_size() {
	echo >>"$report"
	echo "$acodec ${profile}k 𝚫: $cur_profile_min…$cur_profile_max s"  >>"$report"
	echo >>"$report"
	return 0
}


print_report_acodec_abs_min_max_delta_size() {
	echo "$acodec absolute 𝚫: $cur_acodec_abs_min…$cur_acodec_abs_max s"  >>"$report"
	echo -en '\n\n'  >>"$report"
	return 0
}

print_config_line() {
	echo -e "\t[$duration]=$(delta_for_config "$cur_duration_max")" >>"$config"
	return 0
}

 # As one test cannot possibly guarantee, that any file would fit the calcula-
#    ted overshooting, delta seconds are increased to cover for the obvious
#    and inevitable incompleteness of this test.
#  $1 – a floating point number
#
#  Calculating the overhead by the specific ratio to the space equivalent
#  to 1 second of playback has a nuance: as bitrates scale, the same amount
#  of overhead, that was 0.01 of the file size on the 48k profile, becomes
#  0.0024 on 196k. Precision at least to the third digit *is a minimum* to
#  take into account the overhead at the higher bitrate (with two digits
#  after the dot the delta would become 0, which is wrong), and to calculate
#  it with some precision, four digits must be used.
#
delta_for_config() {
	local delta="$1"
	[[ "$delta" =~ ^(-?)[0-9]*(\.[0-9]+|)$ ]]

	 # If the delta is negative, it seems good, but probably a lack of the
	#  testing. So treat below zero delta as the minimal seen around.
	#
	[ "${BASH_REMATCH[1]}" = '-' ]  && delta=0.001

	# if [ "$(echo "scale=$bc_scale; $delta +0.5 >= 1" | bc)" = 1 ]; then
	# 	#  If the delta is 1±.5 second or higher, multiply the delta by 2
	# 	multiplier=2

	# elif [ "$(echo "scale=$bc_scale; $delta +0.05 >= 0.1" | bc)" = 1 ]; then
	# 	#  If the delta is 0.1±.05 second or higher, multiply the delta by 4
	# 	multiplier=4

	# else
	# 	#  If the delta is 0.01…0.04 second, multiply the delta by 10
	# 	multiplier=10

	# fi

	 # Before the shift from the two-digit precision to the four-digit,
	#    the uncaught overhead was supposed to be calculated by scaling the
	#    multiplier, when the delta was below 0.04. Initially there was an
	#    impression, that the disperse of the delta across different codecs
	#    exceeds one second and slows down, as it goes beyond one second,
	#    but later it turend out, that it does not. Using a single multiplier
	#    for all profiles and durations should scale well.
	#  To cover for the cases outside of the range of this test, the multi-
	#    plier must be doubled, or even tripled, however, for the most cases
	#    doubling is expected to be excessive. For a good measure, to cover up
	#    the possibility, that the 2× multiplier may not be enough, it was
	#    increased to 2.5.
	multiplier=2.5
	echo "scale=$bc_scale; $delta * $multiplier" | bc
	return 0
}


do_test() {
	for acodec in "${acodecs[@]}"; do
		#  For all lines but first use 3× \n
		[ -v profile ] && echo -en '\n\n\n'
		if [ "$acodec" != flac ]; then
			declare -n acodec_profiles="${acodec}_profiles"
		else
			acodec_profiles=([0]='')
		fi
		declare ${acodec}_abs_min_delta_size_sec=99999
		declare ${acodec}_abs_max_delta_size_sec=-99999
		declare -n cur_acodec_abs_min=${acodec}_abs_min_delta_size_sec
		declare -n cur_acodec_abs_max=${acodec}_abs_max_delta_size_sec
		for profile in ${!acodec_profiles[*]}; do
			acodec_opts=${acodec_profiles[$profile]}
			acodec_opts="-c:a $acodec  $acodec_opts "
			[ "$acodec" != flac ] && acodec_opts+=" -ac 2"
			declare ${acodec}_${profile}_min_delta_size_sec=99999
			declare ${acodec}_${profile}_max_delta_size_sec=-99999
			declare -n cur_profile_min=${acodec}_${profile}_min_delta_size_sec
			declare -n cur_profile_max=${acodec}_${profile}_max_delta_size_sec

			[ "$acodec" != flac ]  \
				&& echo "${acodec}_${profile}_size_deviations_per_duration=(" >>"$config"

			for duration in "${durations[@]}"; do

				declare ${acodec}_${profile}_${duration}_min_delta_size_sec=99999
				declare ${acodec}_${profile}_${duration}_max_delta_size_sec=-99999
				declare -n cur_duration_min=${acodec}_${profile}_${duration}_min_delta_size_sec
				declare -n cur_duration_max=${acodec}_${profile}_${duration}_max_delta_size_sec

				output_fname="$acodec-$profile-rublev-$duration.mka"
				$ffmpeg -ss "49:53" -t "$duration" -i "$rublev" -map 0:a:2 -vn -sn $acodec_opts "$output_fname"
				[ "$acodec" != flac ] && {
					calc_data
					print_report_line 'rublev'
				}

				output_fname="$acodec-$profile-lovelab-$duration.mka"
				$ffmpeg -ss  "2:32" -t "$duration" -i "$lovelab" -vn -sn  $acodec_opts "$output_fname"
				[ "$acodec" != flac ] && {
					calc_data
					print_report_line 'lovelab'
				}

				output_fname="$acodec-$profile-patema-$duration.mka"
				$ffmpeg -ss "39:30" -t "$duration" -i "$patema" -vn -sn $acodec_opts "$output_fname"
				[ "$acodec" != flac ] && {
					calc_data
					print_report_line 'patema'
					print_config_line
				}

			done


			[ "$acodec" != flac ] && {
				print_report_profile_min_max_delta_size
				echo -e ")\n" >>"$config"
			}

		done


		[ "$acodec" != flac ] && {
			print_report_acodec_abs_min_max_delta_size
			echo -e "\n\n" >>"$config"
		}

	done

	cat <<-EOF | sed "s/^/$(sed -r 's/[^\;]//g; ' <<<"$csv_header")/g"  >>"$report"



	SOFTWARE VERSIONS

	Created with audio_transcode.sh v$version, part of Nadeshiko suite.

	$(ffmpeg -version)

	$(qlist -ICv qlist -ICv opus libvorbis fdk-aac media-sound/lame)

	$(mkvextract --version)

	$("$mypath/../../nadeshiko.sh" --version | head -n1)

	$(LC_TIME=C date +%_d\ %B\ %Y,\ %T)
	EOF

	return 0
}



#  There will be a lot of audio files and a temp file, so you don’t want
#  to run this test many times on your HDD or SSD.
if [ -d /tmp/testdata ]; then
	rm -rf /tmp/testdata/*
else
	mkdir /tmp/testdata
fi
cd /tmp/testdata

do_test

exit 0