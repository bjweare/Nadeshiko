#  Should be sourced.

#  nadeshiko-mpv_dialogues_gtk.sh
#  Dialogues implemented with Python and Glade. I rate them 4.5/5.
#  deterenkelt © 2018
#
#  For licence see nadeshiko.sh


glade_file="$MYDIR/modules/nadeshiko-mpv_dialogues_gtk.glade"
py_file="$MYDIR/modules/nadeshiko-mpv_dialogues_gtk.py"

cp "$glade_file" "$TMPDIR"
cp "$py_file" "$TMPDIR"

glade_file="$TMPDIR/${glade_file##*/}"
py_file="$TMPDIR/${py_file##*/}"


get_copy_of_radiobutton_xml() {
	declare -g xml_copy
	local rb="$1"
	xml_copy=$(
		#  We must operate on the entire <child>
		#  in order to be able to duplicate elements.
		xml sel -t -c "//child[child::object[@id='$rb']]" "$glade_file"
	)
	return 0
}


edit_attr_in_xml() {
	local varname="$1"  xpath="$2"  value="$3"  xmlbuf
	declare -g "$varname"
	declare -gn varval="$varname"
	xmlbuf="$varval"
	varval=$( xml ed -O  -u "$xpath"  -v "$value"  <<<"$xmlbuf" )
	return 0
}


delete_entity_in_xml() {
	local varname="$1"  xpath="$2"  xmlbuf
	declare -g "$varname"
	declare -gn varval="$varname"
	xmlbuf="$varval"
	varval=$( xml ed -O  -d "$xpath"  <<<"$xmlbuf" )
	return 0
}


put_mark_in_xml() {
	local varname="$1"  xpath="$2"  xmlbuf
	declare -g "$varname"
	declare -gn varval="$varname"
	xmlbuf="$varval"
	varval=$( xml ed -O  -s "$xpath"  -t elem  -n "puthere"  <<<"$xmlbuf" )
	return 0
}


insert_one_xml_into_another() {
	local varname="$1"  xml_to_insert="$2"  xmlbuf
	declare -g "$varname"
	declare -gn varval="$varname"
	xmlbuf="$varval"
	echo "$xml_to_insert"  > "$TMPDIR/xml_to_insert"
	varval=$(
		sed -r "/^\s*<puthere\/>\s*$/ {
		                                s/.*//
		                                r $TMPDIR/xml_to_insert
		                              }"  <<<"$xmlbuf"
	)
	return 0
}


update_path_to_glade_file_in_py_file() {
	sed -ri "s~(\s*builder\.add_from_file\(').*('\)\s*)~\1$glade_file\2~"  \
	        "$py_file"
	return 0
}


 # Prepares .glade and .py files: replaces placeholder for names, labels
#  and creates new items.
#  $1..n – radiolist items, as passed from Nadeshiko-mpv.
#
prepare_dotglade_and_dotpy() {
	declare -g entire_xml  glade_file  py_file  xml_copy
	local items_data=( "$@" )  items_count  i  \
	      rb_type  rb2_xml_copy  \
	      add_py_props="$TMPDIR/add_py_props"  \
	      add_py_ifs="$TMPDIR/add_py_ifs"

	 # dialog_items_list is an array, where every three elements represent
	#  a radiobox list item:
	#    - string for the output
	#    - string to display in the dialog
	#    - “on” or “off” to indicate which rb is active
	items_count=$(( ${#items_data[@]} /3 ))
	#  Each rb list already has a group of rb buttons, so we drop every third
	#  item for convenience.
	# for ((i=1; i<${#dialog_items_list[@]}+1; i++)); do
	# 	[ $((i % 3)) -eq 0 ] || items_data+=( "${dialog_items_list[i-1]}" )
	# done

	case "${FUNCNAME[1]}" in
		*choose_mpv_socket*)
			rb_type='socket'
			;;
		*choose_config_file*)
			rb_type='config'
			;;
		*pick_size*)
			rb_type='size'
			;;
	esac

	entire_xml=$( <"$glade_file" )

	[ "$rb_type" = size ] && {
		#  Magic is not needed, quickly replace some data and return.
		for ((i=0; i<4; i++)); do
			edit_attr_in_xml 'entire_xml' \
			                 "//object[@id='rb_${rb_type}$((i+1))']/property[@name='name']" \
			                 "${items_data[3*i]}"
			edit_attr_in_xml 'entire_xml' \
			                 "//object[@id='rb_${rb_type}$((i+1))']/property[@name='label']" \
			                 "${items_data[3*i+1]}"
			if [ "${items_data[3*i+2]}" = on ]; then
				edit_attr_in_xml 'entire_xml' \
			                 "//object[@id='rb_${rb_type}$((i+1))']/property[@name='active']" \
			                 'True'
			else
				delete_entity_in_xml 'entire_xml' \
			                         "//object[@id='rb_${rb_type}$((i+1))']/property[@name='active']"
			fi
		done
		echo "$entire_xml"  > "$glade_file"
		update_path_to_glade_file_in_py_file
		return 0
	}

	#  The following code is more complex and is for socket and configuration
	#  file lists, which number is not predictable.

	edit_attr_in_xml 'entire_xml' \
	                 "//object[@id='rb_${rb_type}1']/property[@name='name']" \
	                 "${items_data[0]}"
	edit_attr_in_xml 'entire_xml' \
	                 "//object[@id='rb_${rb_type}1']/property[@name='label']" \
	                 "${items_data[1]}"
	edit_attr_in_xml 'entire_xml' \
	                 "//object[@id='rb_${rb_type}2']/property[@name='name']" \
	                 "${items_data[3]}"
	edit_attr_in_xml 'entire_xml' \
	                 "//object[@id='rb_${rb_type}2']/property[@name='label']" \
	                 "${items_data[4]}"
	((items_count > 2)) && {
		get_copy_of_radiobutton_xml "rb_${rb_type}2"
		rb2_xml_copy="$xml_copy"
		for ((i=0+2; i<items_count; i++)); do
			new_rb_xml="$rb2_xml_copy"
			new_rb_id="rb_${rb_type}$((i+1))"
			edit_attr_in_xml 'new_rb_xml' \
			                 "//object[@id='rb_${rb_type}2']/@id" \
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
			put_mark_in_xml 'entire_xml'  \
			                "//object[@id='gtkbox_choose_$rb_type']/child/object[@class='GtkBox']"
			insert_one_xml_into_another 'entire_xml'  "$new_rb_xml"
		done
	}
	echo "$entire_xml"  > "$glade_file"

	#  Now preparing $py_file
	((items_count > 2)) && {
		rm -f "$add_py_props" "$add_py_ifs"
		for ((i=0+3; i<items_count+1; i++)); do
			echo -e "\t\tself.rb_$rb_type$i = builder.get_object('rb_$rb_type$i')" \
				>>"$add_py_props"
			echo -e "\t\tif self.rb_$rb_type$i.get_active():"  \
				>>"$add_py_ifs"
			echo -e "\t\t\tprint ( self.rb_$rb_type$i.get_name() )"  \
				>>"$add_py_ifs"
		done
		sed -ri "/^\s*self\.rb_${rb_type}2 = .*/ \
		         r $add_py_props"  "$py_file"
		sed -ri "/^\s*print\s*\(\s*self\.rb_${rb_type}2\.get_name\(\)\s*\)/ \
		         r $add_py_ifs"  "$py_file"
	}
	update_path_to_glade_file_in_py_file
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
	elif [ $pyfile_retval -eq 1 ]; then
		err 'Cannot run gtk dialog: Python code error.'
	elif [ $pyfile_retval -eq 2 ]; then
		err 'Cannot run gtk dialog: “Gtk” Python module is not available.'
	elif [ $pyfile_retval -eq 3 ]; then
		err 'Cannot run gtk dialog: wrong startpage= argument.'
	elif [ $pyfile_retval -eq 4 ]; then
		case ${FUNCNAME[1]} in
			*pick_size*) rm "$data_file";;
		esac
		abort 'Cancelled.'
	elif [ $pyfile_retval -eq 127 ]; then
		err 'Cannot run gtk dialog: env couldn’t find python interpreter.'
	elif [ $pyfile_retval -eq 137 ]; then
		err 'Gtk dialog process was killed.'
	else
		err 'Cannot run gtk dialog: unknown error.'
	fi
}


show_dialogue_choose_mpv_socket_gtk() {
	declare -g mpv_socket
	local dialog_retval
	prepare_dotglade_and_dotpy "${dialog_socket_list[@]}"
	errexit_off
	mpv_socket=$( "$py_file"  startpage=gtkbox_choose_socket )
	dialog_retval=$?
	errexit_on
	check_pyfile_exit_code $dialog_retval
	return 0
}


show_dialogue_choose_config_file_gtk() {
	declare -g nadeshiko_config
	local   dialog_retval
	prepare_dotglade_and_dotpy "${dialog_configs_list[@]}"
	errexit_off
	nadeshiko_config=$( "$py_file"  startpage=gtkbox_choose_config )
	dialog_retval=$?
	errexit_on
	check_pyfile_exit_code $dialog_retval
	return 0
}


show_dialogue_pick_size_gtk() {
	declare -g postpone
	local dialog_output  dialog_retval  chosen_max_size  fname_pfx_entry  \
	      postpone_flag
	prepare_dotglade_and_dotpy "${variants[@]}"
	errexit_off
	dialog_output=$( "$py_file"  startpage=gtkbox_pick_size )
	dialog_retval=$?
	errexit_on
	check_pyfile_exit_code $dialog_retval
	IFS=$'\n' read -d ''  chosen_max_size  fname_pfx_entry  postpone_flag  \
		< <(echo -e "$dialog_output\0");
	write_var_to_datafile max_size "$chosen_max_size"

	! [[ "$fname_pfx_entry" =~ ^[[:space:]]*$ ]]  \
		&& write_var_to_datafile  fname_pfx  "$fname_pfx_entry"

	if [ "$postpone_flag" = postpone ]; then
		write_var_to_datafile  postpone  "$postpone_flag"
		postpone=t
	elif [ "$postpone_flag" = run_now ]; then
		: not writing it to datafile, as it will set postpone as a global.
	else
		err 'Gtk dialog returned an unknown value for postpone_flag.'
	fi
	return 0
}


return 0