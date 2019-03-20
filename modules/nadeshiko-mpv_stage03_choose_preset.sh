#  Should be sourced.

#  nadeshiko-mpv_stage03_choose_preset.sh
#  Nadeshiko-mpv module that allows to choose the desired file size and
#  the video codec based on the preset files placed in CONFDIR.
#  Runs predictor and scene complexity test.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko-mpv.sh


prepare_preset_info() {
	local preset_info=''
	#  Line 1
	preset_info+="$ffmpeg_vcodec ($ffmpeg_pix_fmt) "
	preset_info+="+ $ffmpeg_acodec → $container;"
	preset_info+='  '
	[ "$subs" = yes ] \
		&& preset_info+="+Subs" \
		|| preset_info+="−Subs" 
	preset_info+=' '
	[ "$audio" = yes ] \
		&& preset_info+="+Audio" \
		|| preset_info+="−Audio"
	preset_info+='\n'
	#  Line 2
	preset_info+='Container own space: '
	preset_info+="<span weight=\"bold\">${container_own_size_pct%\%}%</span>"
	preset_info+='\n'
	#  Line 3
	preset_info+='Minimal bitrate perc.: '
	[ "${scene_complexity:-}" = dynamic ] \
		&& preset_info+="<span fgalpha=\"50%\" weight=\"bold\">${minimal_bitrate_pct%\%}%</span>" \
		|| preset_info+="<span weight=\"bold\">${minimal_bitrate_pct%\%}%</span>"
	[ -v scene_complexity ] \
		&& preset_info+="  (source is $scene_complexity)"
	echo "$preset_info"
	return 0
}


 # Reads config values for max_size_normal etc, converts [kMG]
#    suffixes to kB, MB or KiB, MiB, determines, which option
#    is set to default
#  $1 – size code, tiny, normal etc.
prepare_size_radiobox_label() {
	local size="$1"
	declare -n size_val="max_size_$size"
	[ "$size" = unlimited ] && size_val='Unlimited'
	if [ "$kilo" = '1000' ]; then
		size_val=${size_val/k/ kB}
		size_val=${size_val/M/ MB}
		size_val=${size_val/G/ GB}
	elif [ "$kilo" = '1024' ]; then
		size_val=${size_val/k/ KiB}
		size_val=${size_val/M/ MiB}
		size_val=${size_val/G/ GiB}
	fi
	#  GTK builder is bugged, so the 6th option wouldn’t
	#    actually work. We need to set active radiobutton
	#    at runtime, and thus need to have some key to distinguish
	#    the radiobutton, that should be activated.
	#  It also lets the user to see which size is the config’s
	#    default, even when the user clicks on another radiobutton.
	[ "$max_size_default" = "$size" ] && size_val+=" – default"
	echo "$size_val"
	return 0
}


 # Checks whether a size code is one of those, that predictor
#    should run for, as it’s specified in the RC file. Returns 0, if
#    size should be analysed, 1 otherwise.
#  $1 – size code, e.g. tiny, normal, small, unlimited, default
if_predictor_runs_for_this_size() {
	local size="$1"  run_predictor
	for s in "${run_predictor_only_for_sizes[@]}"; do
		if	[ "$s" = "$size" ] \
			|| [ "$s" = 'default'  -a  "$max_size_default" = "$size" ]
		then
			run_predictor=t
			break
		fi
	done
	[ -v run_predictor ] \
		&& return 0  \
		|| return 1
}


 # Composes a list of options for a preset_option_array_N
#    and returns it on stdout.
#  Being launched within a subshell, this function reads Nadeshiko config
#    files (rc files, presets) and executes Nadeshiko in dry run mode
#    several times to get information about how the video clip would
#    (or would not) fit at the possible maximum file size from the preset.
#  $1 – nadeshiko config in CONFDIR to use.
# [$2] – scene_complexity to assume (for the second run and further).
#
prepare_preset_options() {
	local nadeshiko_preset="$1"  nadeshiko_preset_name="$2"  size  \
	      scene_complexity  option_list=()  lastline_in_lastlog  \
	      native_profile  preset_fitmark  preset_fitdesc  i  \
	      running_preset_mpv_msg
	[ "${3:-}" ] && scene_complexity="$3"
	declare -A codec_names_as_formats
	declare -a known_sub_codecs
	declare -a can_be_used_together
	declare -A bitres_profile_360p \
	           bitres_profile_480p \
	           bitres_profile_576p \
	           bitres_profile_720p \
	           bitres_profile_1080p \
	           bitres_profile_1440p \
	           bitres_profile_2160p
	declare -A ffmpeg_subtitle_fallback_style

	info "Preset: $nadeshiko_preset"                                   >&2
	#                                              notice me, senpai!  ^^^
	milinc
	. "$EXAMPLECONFDIR/example.nadeshiko.rc.sh" \
		|| err "Cannot read example.nadeshiko.rc.sh"
	. "$CONFDIR/$nadeshiko_preset" \
		|| err "$nadeshiko_preset doesn’t exist or is not readable."

	 # Preset options for the dialogue window
	#
	#  1. Preset file name (config file name), that the dialogue
	#     should return in stdout later.
	option_list=( "$nadeshiko_preset" )

	#  2. Preset display name, that the dialogue uses
	#     for tab title
	option_list+=( "$nadeshiko_preset_name" )

	#  3. Brief description of the configuration for the popup
	option_list+=( "$( prepare_preset_info  2>&1)" )

	if [ -v predictor ]; then
		#  4. Source video description.
		#     Without predictor it’s unknown, but if predictor is enabled,
		#     then it will be set on the first dry run.
		option_list+=( ' ' )
	else
		option_list+=( 'Unknown' )
	fi

	for size in unlimited normal small tiny; do
		[ ! -v predictor ] && {
			option_list+=(
				"$size"
				"$( prepare_size_radiobox_label "$size"  2>&1 )"
				"$( [ "$max_size_default" = "$size" ] \
						&& echo on  \
						|| echo off  )"
				'-'
				'Predictor disabled'
			)
			continue
		}

		#  This saves several predictor runs.
		[ "$size" = unlimited ] && {
			option_list+=(
				"$size"
				"$( prepare_size_radiobox_label "$size"  2>&1 )"
				"$( [ "$max_size_default" = "$size" ] \
						&& echo on  \
						|| echo off  )"
				'='
				"$( [ -v native_profile ] \
				        && echo "$native_profile" \
				        || echo '<Native>p'  )"
			)
			continue
		}

		if_predictor_runs_for_this_size "$size" || {
			option_list+=(
				"$size"
				"$( prepare_size_radiobox_label "$size"  2>&1 )"
				"$( [ "$max_size_default" = "$size" ] \
						&& echo on  \
						|| echo off  )"
				'#'
				' '  #  User has intentionally skipped this step, they
				     #    want to clearly see only what they need, hence
				     #    the only sizes they use for predictor will stand
				     #    out better, if there will be less clutter around.
				     #  There will be a tooltip for the “…” mark to leave
				     #    a note about skipping for those who may have
				     #    questions.
			)
			continue
		}

		info "Size: $size"                                             >&2
		milinc
		running_preset_mpv_msg='Running Nadeshiko predictor'
		running_preset_mpv_msg+="\nPreset: “$nadeshiko_preset_name”"
		[ "$size" = "$max_size_default" ] \
			&& running_preset_mpv_msg+="\nSize: “default”" \
			|| running_preset_mpv_msg+="\nSize: “$size”"
		if [ -v scene_complexity ]; then
			send_command  show-text "$running_preset_mpv_msg" $((10*1000))
		else
			running_preset_mpv_msg+="\n\nDetermining scene complexity…"
			send_command  show-text "$running_preset_mpv_msg" $((20*60*1000))
		fi
		#  Expecting exit codes either 0 or 5  (fits or doesn’t fit)
		errexit_off

		env  \
			LOGDIR="$TMPDIR"     \
			VERBOSITY_LEVEL=300  \
			"$MYDIR/nadeshiko.sh" "$nadeshiko_preset"            \
			                      "${time1[ts]}" "${time2[ts]}"  \
			                      "$size" "$path"                \
			                      ${crop:+crop=$crop}            \
			                      dryrun                         \
			                      ${scene_complexity:+force_scene_complexity=$scene_complexity}

		errexit_on
		info 'Getting the path to the last log.'                       >&2
		LOGDIR="$TMPDIR" \
		read_lastlog 'nadeshiko' || err 'Nadeshiko didn’t write a log.'
		lastline_in_lastlog=${LASTLOG_TEXT##*$'\n'}
		grep -qE '(Encoding with|Cannot fit)' <<<"$lastline_in_lastlog" || {
			warn 'Nadeshiko couldn’t perform the scene complexity test!'
			echo -en "${__mi}${__y}${__bri}+++ Nadeshiko log "         >&2
			for ((i=0; i<TERM_COLS-18-${#__mi}; i++)); do
				echo -n '+'                                            >&2
			done
			#  Bad idea: to add a spacing “echo”.
			#  It would confuse the one reading the log with a question
			#  “Does this space belong to the log? Is this what causes
			#   an error?”
			echo -e "${__s}"                                           >&2
			sed -r "s/.*/${__mi}&/" "$LASTLOG_PATH"                    >&2
			#  Bad idea: to add a spacing “echo” (see above).
			echo -en "${__mi}${__y}${__bri}+++ End of Nadeshiko log "  >&2
			for ((i=0; i<TERM_COLS-25-${#__mi}; i++)); do
				echo -n '+'                                            >&2
			done
			echo -e "${__s}"                                           >&2
			err 'Error while parsing Nadeshiko log.'
		}

		[ -v scene_complexity ] || {    #  Once.
			info 'Reading scene complexity from the log.'              >&2
			scene_complexity=$(
				sed -rn 's/\s*\*\s*Scene complexity:\s(static|dynamic).*/\1/p' \
					<<<"$LASTLOG_TEXT"
			)
			if [[ "$scene_complexity" =~ ^(static|dynamic)$ ]]; then
				info "Determined scene complexity as $scene_complexity."  >&2
				#  Updating preset info now that we know scene complexity.
				option_list[2]="$( prepare_preset_info  2>&1)"
				[ "${option_list[3]}" = ' ' ] && {
					#  4. Updating source video description.
					option_list[3]="$scene_complexity"
				}
			else
				warn-ns "Couldn’t determine scene complexity."         >&2
				scene_complexity='dynamic'
			fi
			echo "$scene_complexity" >"$TMPDIR/scene_complexity"
		}

		unset bitrate_corrections
		grep -qF 'Bitrate corrections to be applied' <<<"$LASTLOG_TEXT" \
			&& bitrate_corrections=t

		container=$(
			sed -rn 's/\s*\*\s*.*\+.*→\s*(.+)\s*.*/\1/p'  <<<"$LASTLOG_TEXT"
		)
		[ "$container" ] || warn-ns 'Couldn’t determine container.'
		info "Container to be used: $container"                        >&2

		native_profile=$(
			sed -rn 's/\s*\* Starting bitres profile: ([0-9]{3,4}p)\./\1/p' \
				<<<"$LASTLOG_TEXT"
		)
		[[ "$native_profile" =~ ^[0-9]{3,4}p$ ]] \
			|| warn-ns 'Couldn’t determine native bitres profile.'     >&2
		info "Native bitres profile for the video: $native_profile"    >&2
		for ((i=0; i<${#option_list[@]}; i++)); do
			[ "${option_list[i]}" = '<Native>p' ] && {
				info "Updating value “Native” in the option_list[$i] to $native_profile." >&2
				[ -v bitrate_corrections ] \
					&& option_list[i]="$native_profile*" \
					|| option_list[i]="$native_profile"
			}
		done

		if [[ "$lastline_in_lastlog" =~ Encoding\ with.*\ ([0-9]+p|Native|Cropped).* ]]; then
			encoding_res_code="${BASH_REMATCH[1]}"
			if [[ "$encoding_res_code" =~ ^(Native|Cropped)$ ]]; then
				preset_fitmark='='
				preset_fitdesc="$native_profile"
			else
				preset_fitmark='v'
				preset_fitdesc="$encoding_res_code"
			fi
			[ -v bitrate_corrections ] && preset_fitdesc+='*'

		elif [[ "$lastline_in_lastlog" =~ Cannot\ fit ]]; then
			preset_fitmark='x'
			preset_fitdesc="Won’t fit"

		else
			preset_fitmark='?'
			preset_fitdesc="Unknown"
			warn-ns 'Unexpected value in Nadeshiko config.'            >&2

		fi

		#  Options 5–9 will be repeating for each row.
		#
		#  5. String to return in stdout, if this radiobox is chosen.
		option_list+=( "$size" )

		#  6. Radiobox label.
		option_list+=( "$(prepare_size_radiobox_label "$size" 2>&1)" )

		#  7. Whether radiobox should be set active.
		option_list+=( "$(
			[ "$max_size_default" = "$size" ] && echo on || echo off
		)" )

		#  8. Code character representing how the clip would fit:
		#     “=” – fits at native resolution
		#     “v” – fits with downscale
		#     “x” – wouldn’t fit.
		option_list+=("$preset_fitmark")

		#  9. String accompanying the code character above, either
		#     a profile resolution, e.g. “1080p” or “Won’t fit”.
		option_list+=("$preset_fitdesc")

		mildec
	done

	mildec
	#  echo’ing the list to stdout to be read into an array,
	#    which name would then be send as an argument to the function
	#    running dialogue window.
	#  W! The last element should *never* be empty, or the readarray -t
	#    command will not see the empty line! It will discard the \n,
	#    and there will be a lost element and a shift in the order.
	IFS=$'\n' ; echo "${option_list[*]}"
	return 0
}


choose_preset() {
	declare -g  mpv_pid  nadeshiko_presets  scene_complexity
	local  i  param_list  preset_idx  gui_default_preset_idx  \
	       ordered_preset_list  temp  \
	       resp_nadeshiko_preset  preset  preset_exists  \
	       resp_max_size  \
	       resp_fname_pfx  \
	       resp_postpone
	check_needed_vars

	#  We’re going to print long-lasting messages on mpv screen, so in case
	#  the program would quit on this stage, make sure to leave screen clean.
	export WIPE_MPV_SCREEN_ON_EXIT=t

	preset_idx=0
	for nadeshiko_preset_name in "${!nadeshiko_presets[@]}"; do
		#  To put the default preset first later.
		[ "$nadeshiko_preset_name" = "$gui_default_preset" ] \
			&& gui_default_preset_idx=$preset_idx
		nadeshiko_preset="${nadeshiko_presets[$nadeshiko_preset_name]}"
		declare -g -a  preset_option_array_$preset_idx
		declare -n current_preset_option_array="preset_option_array_$preset_idx"
		[ ! -v scene_complexity  -a  -r "$TMPDIR/scene_complexity" ]  \
			&& read scene_complexity  <"$TMPDIR/scene_complexity"
		#  Subshell call is necessary here
		#  to sandbox the sourcing of Nadeshiko config files.
		param_list=$(
			prepare_preset_options "$nadeshiko_preset"  \
			                       "$nadeshiko_preset_name"   \
			                       ${scene_complexity:-}
		)
		echo
		info "Options for preset $nadeshiko_preset:"
		declare -p param_list
		readarray -d $'\n'  -t  current_preset_option_array  <<<"$param_list"
		let ++preset_idx
	done

	#  No long-lasting messages are to be printed now, so unset the variable.
	unset WIPE_MPV_SCREEN_ON_EXIT

	#  Placing the default preset first to be opened in GUI by default.
	ordered_preset_list=( ${!preset_option_array_*} )
	[ "${ordered_preset_list[0]}" != preset_option_array_$gui_default_preset_idx ] && {
		temp="${ordered_preset_list[0]}"
		ordered_preset_list[0]="preset_option_array_$gui_default_preset_idx"
		ordered_preset_list[gui_default_preset_idx]="$temp"
	}

	echo
	info "Dispatching options to dialogue window:"
	declare -p ordered_preset_list
	declare -p ${!preset_option_array_*}
	send_command  show-text 'Building GUI' '3000'
	show_dialogue_choose_preset "${ordered_preset_list[@]}"

	IFS=$'\n' read -r -d ''  resp_nadeshiko_preset  \
	                         resp_max_size          \
	                         resp_fname_pfx         \
	                         resp_postpone          \
		< <(echo -e "$dialog_output\0")
	#  Verifying data
	for preset in ${nadeshiko_presets[@]}; do
		[ "$resp_nadeshiko_preset" = "$preset" ] && preset_exists=t
	done
	if [ -v preset_exists ]; then
		write_var_to_datafile nadeshiko_preset "$resp_nadeshiko_preset"
	else
		err 'Dialog didn’t return a valid Nadeshiko preset.'
	fi

	if [[ "$resp_max_size" =~ ^(tiny|small|normal|unlimited)$ ]]; then
		write_var_to_datafile max_size "$resp_max_size"
	else
		err 'Dialog didn’t return a valid maximum size code.'
	fi

	! [[ "$resp_fname_pfx" =~ ^[[:space:]]*$ ]]  \
		&& write_var_to_datafile  fname_pfx  "$resp_fname_pfx"

	if [ "$resp_postpone" = postpone ]; then
		write_var_to_datafile  postpone  "$resp_postpone"
	elif [ "$resp_postpone" = run_now ]; then
		#  keeping postpone unset, as writing it to datafile will set it
		#  as a global variable.
		:
	else
		err 'Dialog returned an unknown value for postpone.'
	fi

	return 0
}


return 0