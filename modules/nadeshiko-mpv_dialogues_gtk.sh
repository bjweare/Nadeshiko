#  Should be sourced.

#  nadeshiko-mpv_dialogues_gtk.sh
#  Dialogues implemented with Python and Glade. I rate them 4.5/5.
#  © deterenkelt 2018
#
#  For licence see nadeshiko.sh


glade_file="$MODULESDIR/nadeshiko-mpv_dialogues_gtk.glade"
py_file="$MODULESDIR/nadeshiko-mpv_dialogues_gtk.py"

cp "$glade_file" "$TMPDIR"
cp "$py_file" "$TMPDIR"

glade_file="$TMPDIR/${glade_file##*/}"
py_file="$TMPDIR/${py_file##*/}"
chmod +x "$py_file"

entire_xml=$( <"$glade_file" )
entire_py_code=$( <"$py_file" )

 # $1 – variable name, that holds the array with dialogue options.
#
prepare_dotglade_and_dotpy_for_sockets() {
	local options_array_varname="$1"  items_data  items_count  \
	      rb2_xml_copy  new_rb_xml  new_rb_id  i
	declare -A py_code
	declare -n items_data="$options_array_varname"

	items_count=$(( ${#items_data[@]} /3 ))

	edit_attr_in_xml 'entire_xml' \
	                 "//object[@id='rb_socket1']/property[@name='name']" \
	                 "${items_data[0]}"
	edit_attr_in_xml 'entire_xml' \
	                 "//object[@id='rb_socket1']/property[@name='label']" \
	                 "${items_data[1]}"
	edit_attr_in_xml 'entire_xml' \
	                 "//object[@id='rb_socket2']/property[@name='name']" \
	                 "${items_data[3]}"
	edit_attr_in_xml 'entire_xml' \
	                 "//object[@id='rb_socket2']/property[@name='label']" \
	                 "${items_data[4]}"
	edit_attr_in_xml 'entire_xml' \
	                 "//object[@id='rb_socket2']/property[@name='active']" \
	                 "False"
	((items_count > 2)) && {
		put_xml_chunk_in_var 'entire_xml'  \
		                     '//child[child::object[@id="rb_socket2"]]' \
		                     'rb2_xml_copy'
		for ((i=0+2; i<items_count; i++)); do
			new_rb_xml="$rb2_xml_copy"
			new_rb_id="rb_socket$((i+1))"
			edit_attr_in_xml 'new_rb_xml' \
			                 "//object[@id='rb_socket2']/@id" \
			                 "$new_rb_id"
			edit_attr_in_xml 'new_rb_xml' \
			                 "//object[@id='$new_rb_id']/property[@name='name']" \
			                 "${items_data[3*i]}"
			edit_attr_in_xml 'new_rb_xml' \
			                 "//object[@id='$new_rb_id']/property[@name='label']" \
			                 "${items_data[3*i+1]}"
			edit_attr_in_xml 'new_rb_xml' \
			                 "//packing/property[@name='position']" \
			                 "$i"
			insert_one_xml_into_another 'entire_xml'  \
			                            "//object[@id='gtkbox_choose_socket']/child/object[@class='GtkBox']" \
			                            "$new_rb_xml"
		done
	}

	#  Now preparing $py_file
	((items_count > 2)) && {
		for ((i=0+3; i<items_count+1; i++)); do
			py_code[EXTRA SELF.RB_SOCKET* CODE]+=$'\t\t\t'"self.rb_socket$i = builder.get_object('rb_socket$i')"$'\n'
			py_code[EXTRA RB_SOCKET* SELECTION CODE]+=$'\t\t\t'"if self.rb_socket$i.get_active():"$'\n'
			py_code[EXTRA RB_SOCKET* SELECTION CODE]+=$'\t\t\t\t'"print ( self.rb_socket$i.get_name() )"$'\n'
		done
		insert_blocks_in_py_code 'entire_py_code' 'py_code'
	}

	write_dotglade_and_dotpy_files
	return 0
}


 # $1 – “pick=on” or “pick=off”. Defines the initial state for the “Pick”
#       button. If it is “off”, then butbox_croptool_installer is shown.
#  $2 – “has_installer=yes” or “has_installer=no”. Defines, whether the
#       “Install crop button” should be available, when crop tool is not
#       installed on the user’s end.
#  $3 – “predictor=on” or “predictor=off”. Defines the initial state
#       for the Predictor switch.
# [$4..7] – (latest stage options) if set, then set determined W:H:X:Y values
#       into the input fields, set cb_crop.active and box_cropsettings.visible
#       to True.
#
prepare_dotglade_and_dotpy_for_crop_and_predictor() {
	local pick_state="$1" has_installer="$2" predictor_state="$3"  \
	      cropw="${4:-}"  croph=${5:-}  cropx="${6:-}"  cropy="${7:-}"
	declare -A py_code

	if  [ "$cropw" ] || [ "$croph" ] || [ "$cropx" ] || [ "$cropy" ];  then

		(
			[[    "$cropw" =~ ^[0-9]{1,4}$  &&  "$croph" =~ ^[0-9]{1,4}$ ]] \
			&& [[ "$cropx" =~ ^[0-9]{1,4}$  &&  "$cropy" =~ ^[0-9]{1,4}$ ]]
		) \
			|| err 'Values 3–6 should be crop width, height, X and Y or not set.'

		#  Filling input fields
		add_obj_property_to_xml 'entire_xml' \
		                        '//object[@id="input_cropw"]' \
		                        'text' \
		                        "$cropw"
		add_obj_property_to_xml 'entire_xml' \
		                        '//object[@id="input_croph"]' \
		                        'text' \
		                        "$croph"
		add_obj_property_to_xml 'entire_xml' \
		                        '//object[@id="input_cropx"]' \
		                        'text' \
		                        "$cropx"
		add_obj_property_to_xml 'entire_xml' \
		                        '//object[@id="input_cropy"]' \
		                        'text' \
		                        "$cropy"
		#  Activating crop checkbox and showing box_cropsettings
		add_obj_property_to_xml 'entire_xml' \
		                        '//object[@id="cb_crop"]' \
		                        'active' \
		                        'True'
		#  Due to the bug № 12 in Developer notes, controlling visibility
		#  for dependent elements is delegated to python code, here only
		#  the visibility of the main element is controlled.

	else
		#  Unticking crop checkbox and hiding box_cropsettings
		add_obj_property_to_xml 'entire_xml' \
		                        '//object[@id="cb_crop"]' \
		                        'active' \
		                        'False'
		#  Due to the bug № 12 in Developer notes, controlling visibility
		#  for dependent elements is delegated to python code, here only
		#  the visibility of the main element is controlled.
	fi

	case "$pick_state" in
		pick=on)
			#  Enable Pick button, disable croptool_installer
			edit_attr_in_xml 'entire_xml' \
			                 '//object[@id="but_pick_cropdims"]/property[@name="sensitive"]' \
			                 'True'
			#  Due to the bug № 12 in Developer notes, controlling visibility
			#  for dependent elements is delegated to python code, here only
			#  the visibility of the main element is controlled.
			;;
		pick=off)
			#  Disable Pick button, enable croptool_installer
			edit_attr_in_xml 'entire_xml' \
			                 '//object[@id="but_pick_cropdims"]/property[@name="sensitive"]' \
			                 'False'
			#  Due to the bug № 12 in Developer notes, controlling visibility
			#  for dependent elements is delegated to python code, here only
			#  the visibility of the main element is controlled.
			;;
		*)
			err "Wrong parameter: “$pick_state”. Expected pick=<on|off>."
			;;
	esac

	case "$predictor_state" in
		predictor=on)
			add_obj_property_to_xml 'entire_xml' \
			                        '//object[@id="switch_predictor"]' \
			                        'active' \
			                        'True'
			;;
		predictor=off)
			add_obj_property_to_xml 'entire_xml' \
			                        '//object[@id="switch_predictor"]' \
			                        'active' \
			                        'False'
			;;
		*)
			err "Wrong parameter: “$predictor_state”. Expected predictor=<on|off>."
			;;
	esac

	#  Delegating the check on has_installer to python.
	[ "$has_installer" = yes ] \
		&& has_installer='True' \
		|| has_installer='False'
	py_code[HAS_INSTALLER CODE]+=$'\t\t\t'"self.has_installer = ${has_installer^}"$'\n'
	insert_blocks_in_py_code 'entire_py_code' 'py_code'

	write_dotglade_and_dotpy_files
	return 0
}


#  $1 – text to display in the window, while croptool is working.
prepare_dotglade_and_dotpy_for_cropping() {
	declare -A py_code
	edit_attr_in_xml 'entire_xml' \
	                 '//object[@id="gtkbox_cropping"]/child/object[@class="GtkLabel"]/property[@name="label"]' \
	                 "$1"
	py_code[TMPDIR CODE]="TMPDIR = '$TMPDIR'"
	insert_blocks_in_py_code 'entire_py_code' 'py_code'
	write_dotglade_and_dotpy_files
	return 0
}


 # $1..n – variable names, that hold arrays with dialogue options.
#          One variable = one indexed array = one Nadeshiko preset (rc.sh)
#          One preset (array) contains 9 items:
#            1. Nadeshiko preset file name (config file name)
#            2. Nadeshiko preset display name, for tab title.
#            3. Short profile description to be displayed in a popup
#               or in status bar. Should have: $ffmpeg_vcodec, $ffmpeg_acodec,
#               $container, $ffmpeg_pix_fmt, $subs, $audio. May also have
#               $container_own_size_pct, $minimal_bitrate_pct
#            4. Source video info. Is used to pass “static” or “dynamic”.
#            (next items come in groups of five)
#            5. maximum size to return to stdout, if this element is chosen,
#               e.g. “tiny”, “small”, “normal”, “unlimited”.
#            6. string to display in the radiobox label
#            7. “on” or “off” to turn the radiobox on or off.
#            8. “=”, “v” or “x” to represent, that at this file size the
#               encoding will preserve native resolution; downscale; be impos-
#               sible.
#            9. a string to be displayed along with the sign above:
#               for “=” and “v” it’s a profile resolution (1080p, 720p…)
#               and for “x” it’s “Won’t fit”.
#          Each preset has four sizes, so items 5–9 are repeated four times.
#
prepare_dotglade_and_dotpy_for_presets(){
	local varnames_of_option_arrays=("$@")  option_array  items_count="$#"  \
	      i  grid_xmlcopy  tab_xmlcopy  current_grid  current_tab  \
	      preset_filename  preset_displayname  preset_desc  video_desc  \
	      rb_name  rb_stdout  rb_label  rb_active  rb_fitmark  rb_fitdesc  \
	      label_name  label_desc  desc_tooltip  radio_buttons  rb  \
	      rb_group_preset_name
	declare -A py_code

	force_enable_cb_postpone() {
		local xpath="//object[@id='cb_postpone']"
		add_obj_property_to_xml  'entire_xml'  \
		                         "$xpath"  \
		                         'active'  \
		                         'True'
		add_obj_property_to_xml  'entire_xml'  \
		                         "$xpath"  \
		                         'sensitive'  \
		                         'False'
		return 0
	}

	 # Take the first three elements out of the array and assign to variables.
	#  The rest will be reassigned to that same array for the ease of itera-
	#  ting over it.
	#  $1 – index of ${varnames_of_option_arrays[*]}, i.e. which preset
	#       (tab) we’re processing.
	prepare_options_1to4() {
		local i=$1
		declare -n option_array=${varnames_of_option_arrays[i]}
		preset_filename="${option_array[0]}"
		preset_displayname="${option_array[1]}"
		preset_desc=$( echo -e "${option_array[2]}" )  # converting '\n'ewlines
		video_desc="${option_array[3]}"
		return 0
	}

	 # Take a portion of five elements out of the array and assign to
	#  option variables.
	#  $1 – index in ${varnames_of_option_arrays[*]}, to point at the options
	#       of current preset/tab/config file
	#  $2 – index to start with in that array, assuming that it all consists
	#       of repetitive radiobox options (i.e. as if the first 4 elements
	#       were striped off: only four rows, each of five elements).
	prepare_options_NtoM() {
		local array_no=$1  offset=$2
		declare -n option_array=${varnames_of_option_arrays[array_no]}
		rb_stdout="${option_array[4+offset]}"
		rb_label="${option_array[4+offset+1]}"
		rb_active="${option_array[4+offset+2]}"
		rb_fitmark="${option_array[4+offset+3]}"
		rb_fitdesc="${option_array[4+offset+4]}"
		return 0
	}

	[ -v postpone ] && force_enable_cb_postpone
	#  remove empty <child type="tab"> with <placeholder/> tag and the
	#  empty “tab” childs.
	delete_entity_in_xml 'entire_xml'  \
	                     '//object[@id="preset_tabs"]/child[child::placeholder]'

	#  Create a copy of grid_with_preset_sizes (← grid within a tab)
	put_xml_chunk_in_var 'entire_xml'  \
	                     '//child[child::object[@id="grid_with_preset_sizes"]]' \
	                     'grid_xmlcopy'

	#  Create a copy of <child type="tab">, that is not empty.
	put_xml_chunk_in_var 'entire_xml'  \
	                     '//object[@id="preset_tabs"]/child[@type="tab"]' \
	                     'tab_xmlcopy'

	#  Remove all childs from tabs_presets – we’ll be filling it anew
	#  or it will be deleted
	delete_entity_in_xml 'entire_xml' \
	                     '//object[@id="preset_tabs"]/child'

	for ((i=0; i<items_count; i++)); do
		#  Prepare array: get config file name, description and set
		#    an array to be processed
		prepare_options_1to4 $i

		current_grid="$grid_xmlcopy"
		edit_attr_in_xml 'current_grid' \
		                 "//object[@id='grid_with_preset_sizes']/@id" \
		                 "grid_with_preset_sizes$i"
		current_tab="$tab_xmlcopy"
		add_obj_property_to_xml 'current_tab'  \
		                        '//object'  \
		                        'name'  \
		                        "$preset_filename"
		add_obj_property_to_xml 'current_tab'  \
		                        '//object'  \
		                        'label'  \
		                        "$preset_displayname"
		add_obj_property_to_xml 'current_tab'  \
		                        '//object'  \
		                        'tooltip_markup'  \
		                        "$preset_desc"

		for ((j=0; j<4; j++)); do
			prepare_options_NtoM $i $((j*5))
			#  Setting radio buttons
			rb_name="rb_size$(( i*4 + j + 1 ))"
			edit_attr_in_xml 'current_grid' \
			                 "//object[@id='rb_size$((j+1))']/@id" \
			                 "$rb_name"
			edit_attr_in_xml 'current_grid' \
			                 "//object[@id='$rb_name']/property[@name='label']" \
			                 "$rb_label"
			edit_attr_in_xml 'current_grid' \
			                 "//object[@id='$rb_name']/property[@name='name']" \
			                 "$rb_stdout"
			[ "$rb_active" = on ] && rb_active='True' || rb_active='False'
			edit_attr_in_xml 'current_grid' \
			                 "//object[@id='$rb_name']/property[@name='active']" \
			                 "$rb_active"
			((j != 0)) && add_obj_property_to_xml 'current_grid' \
				                                  "//object[@id='$rb_name']" \
				                                  'group' \
				                                  "rb_size$(( i*4 + 1 ))"
			#  Setting marks
			label_name="label_fitmark$(( i*4 + j + 1 ))"
			label_desc="label_fitdesc$(( i*4 + j + 1 ))"
			edit_attr_in_xml 'current_grid' \
			                 "//object[@id='label_fitmark$((j+1))']/@id" \
			                 "$label_name"
			edit_attr_in_xml 'current_grid' \
			                 "//object[@id='label_fitdesc$((j+1))']/@id" \
			                 "$label_desc"
			edit_attr_in_xml 'current_grid' \
			                 "//object[@id='$label_desc']/property[@name='label']" \
			                 "$rb_fitdesc"

			case "$rb_fitmark" in

				"=")
					#  Mark
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_name']/property[@name='label']" \
					                 "="
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_name']/property[@name='tooltip_text']" \
					                 "Will preserve native resolution."
					add_obj_property_to_xml 'current_grid' \
					                        "//object[@id='$label_name']" \
					                        'margin_bottom' \
					                        '1'
					add_obj_property_to_xml 'current_grid' \
					                        "//object[@id='$label_name']" \
					                        'angle' \
					                        '0'
					#  Desc
					desc_tooltip='Bitrate-resolution profile to be used.'
					[[ "$rb_fitdesc" =~ \*$ ]] && desc_tooltip+="

* Profile bitrates will be additionally adjusted for the output resolution."
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_desc']/property[@name='tooltip_text']" \
					                 "$desc_tooltip"
					;;

				"v")
					#  Mark
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_name']/property[@name='label']" \
					                 "‣"
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_name']/property[@name='tooltip_text']" \
					                 "Will have to be downscaled."
					add_obj_property_to_xml 'current_grid' \
					                        "//object[@id='$label_name']" \
					                        'margin_bottom' \
					                        '0'
					add_obj_property_to_xml 'current_grid' \
					                        "//object[@id='$label_name']" \
					                        'angle' \
					                        '270'
					#  Desc
					desc_tooltip='Bitrate-resolution profile to be used.'
					[[ "$rb_fitdesc" =~ \*$ ]] && desc_tooltip+="

* Profile bitrates will be additionally adjusted for the output resolution."
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_desc']/property[@name='tooltip_text']" \
					                 "$desc_tooltip"
					;;

				"x")
					#  Mark
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_name']/property[@name='label']" \
					                 "×"
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_name']/property[@name='tooltip_text']" \
					                 "Impossible to encode."
					add_obj_property_to_xml 'current_grid' \
					                        "//object[@id='$label_name']" \
					                        'margin_bottom' \
					                        '0'
					add_obj_property_to_xml 'current_grid' \
					                        "//object[@id='$label_name']" \
					                        'angle' \
					                        '0'
					#  Desc
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_desc']/property[@name='tooltip_text']" \
					                 "Clip duration is too long to preserve good quality even at the smallest resolution."
					;;

				"?")
					#  Mark
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_name']/property[@name='label']" \
					                 "?"
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_name']/property[@name='tooltip_text']" \
					                 "Unknown."
					#  ?’s mass is too heavy, change font size from 14 pt to 12.
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_name']/attributes/attribute[@name='font-desc']/@value" \
					                 'Roboto 12'
					add_obj_property_to_xml 'current_grid' \
					                        "//object[@id='$label_name']" \
					                        'margin_bottom' \
					                        '0'
					add_obj_property_to_xml 'current_grid' \
					                        "//object[@id='$label_name']" \
					                        'angle' \
					                        '0'
					#  Desc
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_desc']/property[@name='tooltip_text']" \
					                 "Predictor couldn’t retrieve the value from Nadeshiko log."
					#  Default opacity for label_fitmark* and label_fitdesc*
					#  is 0.92
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_desc']/property[@name='opacity']" \
					                 "0.4"
					;;

				"#")
					#  Mark
					#  The mark initially should have been “⋯”, but due to
					#    font substitution issues, it may be not rendered
					#    properly. When/if characters would be replaced with
					#    icons, there probably should be one like “⋯”, not “#”.
					#  Though “#” has a better mass and a connotation with
					#    jailing. So maybe it should stay.
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_name']/property[@name='label']" \
					                 "#"
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_name']/property[@name='tooltip_text']" \
					                 "Skipped to save time. Configure predictor in the RC file to change."
					#  #’s mass is too heavy, change font size from 14 pt to 12.
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_name']/attributes/attribute[@name='font-desc']/@value" \
					                 'Roboto 12'
					add_obj_property_to_xml 'current_grid' \
					                        "//object[@id='$label_name']" \
					                        'margin_bottom' \
					                        '0'
					add_obj_property_to_xml 'current_grid' \
					                        "//object[@id='$label_name']" \
					                        'angle' \
					                        '0'
					#  Because there’s only a mark without a description,
					#    it visually ties both vertically and horizontally.
					#    This creates a possible confusion, that it is related
					#    more to the other marks, than those marks’ descrip-
					#    tive text. To help the mark descriptions to be per-
					#    ceived as a whole with their marks, and portrait lone
					#    “#” mark more separately, we make an exception and
					#    draw this mark with a decreased opacity.
					#  Default opacity for label_fitmark* and label_fitdesc*
					#    is 0.92.
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_name']/property[@name='opacity']" \
					                 "0.4"
					#  Desc
					delete_entity_in_xml 'current_grid' \
					                     "//object[@id='$label_desc']/property[@name='tooltip_text']"
					# edit_attr_in_xml 'current_grid' \
					#                  "//object[@id='$label_desc']/property[@name='tooltip_text']" \
					#                  ""
					#  Default opacity for label_fitmark* and label_fitdesc*
					#  is 0.92
					# edit_attr_in_xml 'current_grid' \
					#                  "//object[@id='$label_desc']/property[@name='opacity']" \
					#                  "0.4"
					;;

				"-")
					#  Mark
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_name']/property[@name='label']" \
					                 ""
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_name']/property[@name='tooltip_text']" \
					                 "Enable predictor in nadeshiko-mpv.rc.sh."
					add_obj_property_to_xml 'current_grid' \
					                        "//object[@id='$label_name']" \
					                        'margin_bottom' \
					                        '0'
					add_obj_property_to_xml 'current_grid' \
					                        "//object[@id='$label_name']" \
					                        'angle' \
					                        '0'
					#  Desc
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_desc']/property[@name='tooltip_text']" \
					                 "Enable predictor in nadeshiko-mpv.rc.sh."
					#  Default opacity for label_fitmark* and label_fitdesc*
					#  is 0.92
					edit_attr_in_xml 'current_grid' \
					                 "//object[@id='$label_desc']/property[@name='opacity']" \
					                 "0.4"
					;;

			esac
		done

		#  Finishing touches for the case with a single preset.
		(( items_count == 1 )) && {
			#  Disable tabs
			#  There’s no need to show tab bar, when there’s only one tab.
			add_obj_property_to_xml 'entire_xml' \
			                        '//object[@id="preset_tabs"]' \
			                        'show_tabs' \
			                        'False'
			#  Reduce padding, that now looks superfluous.
			#  Without the tab bar, tab area background now doesn’t differ
			#  from the window background any more. (God dammit…)
			edit_attr_in_xml 'entire_xml' \
			                 '//object[@id="preset_tabs"]/property[@name="margin_top"]' \
			                 '4'
			edit_attr_in_xml 'entire_xml' \
			                 '//object[@id="cb_set_fname_pfx"]/property[@name="margin_top"]' \
			                 '4'
			#  Remove the mention of presets from the header bar.
			edit_attr_in_xml 'entire_xml' \
			                 '//object[@id="headerbar_pick_size"]/property[@name="title"]' \
			                 'Choose maximum size'
		}

		#  All grids and tabs prepared, time to put them in the window.
		#  <Children> must be placed AFTER <properties>!
		insert_one_xml_into_another 'entire_xml' \
		                            '//object[@id="preset_tabs"]' \
		                            "$current_grid"
		insert_one_xml_into_another 'entire_xml' \
		                            '//object[@id="preset_tabs"]' \
		                            "$current_tab"
	done

	#  Now preparing .py file
	readarray -d $'\n' -t radio_buttons \
		< <( $xml sel -t -v '//object[@class="GtkRadioButton"]/@id' \
		     <<<"$entire_xml" | grep rb_size )

	for rb in ${radio_buttons[@]}; do
		py_code[SELF.RB_SIZE* CODE]+=$'\t\t\t'"self.$rb = builder.get_object('$rb')"$'\n'
		py_code[RB_SIZE* ACTIVATION CODE]+=$'\t\t\t'"if self.$rb.get_label()[-7:] == 'default':"$'\n'
		py_code[RB_SIZE* ACTIVATION CODE]+=$'\t\t\t\t'"self.$rb.set_active(True)"$'\n'
		#  Getting the preset name to which current $rb belongs.
		#  rb_size* objects in XML start from 1, so subtracting 1.
		declare -n option_array=${varnames_of_option_arrays[$((  ( ${rb#rb_size}-1 ) /4  ))]}
		rb_group_preset_name="${option_array[0]}"
		py_code[RB_SIZE* SELECTION CODE]+=$'\t\t'"if chosen_preset == \"$rb_group_preset_name\"  and  self.$rb.get_active():"$'\n'
		py_code[RB_SIZE* SELECTION CODE]+=$'\t\t\t'"print ( self.$rb.get_name() )"$'\n'
	done

	insert_blocks_in_py_code 'entire_py_code' 'py_code'
	write_dotglade_and_dotpy_files
	return 0
}


#
#  Actual dialogue functions
#

check_pyfile_exit_code() {
	declare -g data_file
	local pyfile_retval="$1"
	if [ $pyfile_retval -eq 0 ]; then
		return 0
	else
		#  Remove $data_file for functions, that passed
		#  over Time1 and Time2 selection stage.
		[[ "${FUNCNAME[1]}" =~ ^.*choose_socket.*$ ]] || {
			#  In the unit test $data_file may be unset.
			[ -v data_file ] && [ -r "$data_file" ] && rm "$data_file"
		}

		if [ $pyfile_retval -eq 1 ]; then
			err 'Cannot run gtk dialog: Python code error.'
		elif [ $pyfile_retval -eq 2 ]; then
			err 'Cannot run gtk dialog: “Gtk” Python module is not available.'
		elif [ $pyfile_retval -eq 3 ]; then
			err 'Cannot run gtk dialog: wrong startpage= argument.'
		elif [ $pyfile_retval -eq 4 ]; then
			abort 'Cancelled.'
		elif [ $pyfile_retval -eq 127 ]; then
			err 'Cannot run gtk dialog: env couldn’t find python interpreter.'
		elif [ $pyfile_retval -eq 137 ]; then
			err 'Gtk dialog process was killed.'
		else
			err 'Cannot run gtk dialog: unknown error.'
		fi
	fi
	return 0
}


#  $1 – variable name that holds array with dialogue options.
#       Socket selection is a part of low-level work,
#       hence it is done from mpv_ipc.sh.
show_dialogue_choose_mpv_socket() {
	declare -g dialog_output
	local dialog_retval
	prepare_dotglade_and_dotpy_for_sockets "$1"
	errexit_off
	dialog_output=$( "$py_file"  startpage=gtkbox_choose_socket )
	dialog_retval=$?
	errexit_on
	info "Dialog output: “$dialog_output”"
	check_pyfile_exit_code $dialog_retval
	return 0
}


show_dialogue_crop_and_predictor() {
	declare -g dialog_output
	local dialog_retval
	prepare_dotglade_and_dotpy_for_crop_and_predictor "$@"
	errexit_off
	dialog_output=$( "$py_file"  startpage=gtkbox_crop_and_predictor )
	dialog_retval=$?
	errexit_on
	info "Dialog output: “$dialog_output”"
	check_pyfile_exit_code $dialog_retval
	return 0
}


show_dialogue_cropping() {
	#  In Nadeshiko-mpv old .py and .glade could be used,
	#  this call is for the unit test.
	prepare_dotglade_and_dotpy_for_cropping "$@"
	#  This window is more like a throwaway notification.
	#  User may close it at any time, however it is intended to stay
	#    as a supportful element, a hint on what to do, something that says
	#    “Hey, I’m still with you, I am waiting for your action”. So it should
	#    remain before the eyes, unless user either performs the action
	#    or decides to close it, because it meddles with cropping.
	#    Though simply moving it away should be enough.
	#  Nadeshiko-mpv closes this window automatically, when file with a proper
	#    name (i.e. with a name containing W:H:X:Y) would be found in TMPDIR.
	"$py_file"  startpage=gtkbox_cropping &
	return 0
}


#  $1..n – variable names, that hold arrays with dialogue options.
#          Here
show_dialogue_choose_preset() {
	declare -g dialog_output
	local dialog_retval
	prepare_dotglade_and_dotpy_for_presets "$@"
	errexit_off
	dialog_output=$( "$py_file"  startpage=gtkbox_pick_size)
	dialog_retval=$?
	errexit_on
	info "Dialog output: “$dialog_output”"
	check_pyfile_exit_code $dialog_retval
	return 0
}


return 0
