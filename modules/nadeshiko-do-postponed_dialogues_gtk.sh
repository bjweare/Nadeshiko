#  Should be sourced.

#  nadeshiko-do-postponed_dialogues_gtk.sh
#  Dialogues implemented with Python and Glade. Can be rated 4.5/5.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh


. "$LIBDIR/xml_and_python_functions.sh"
glade_file="$MODULESDIR/nadeshiko-do-postponed_dialogues_gtk.glade"
py_file="$MODULESDIR/nadeshiko-do-postponed_dialogues_gtk.py"

cp "$glade_file" "$TMPDIR"
cp "$py_file" "$TMPDIR"

glade_file="$TMPDIR/${glade_file##*/}"
py_file="$TMPDIR/${py_file##*/}"
chmod +x "$py_file"

entire_xml=$( <"$glade_file" )
entire_py_code=$( <"$py_file" )


#  $1 – number of jobs, that are postponed.
prepare_dotglade_for_launch_jobs() {
	local jobs_to_run="$1" failed_jobs="$2" message=''  run_job_button_text
	if [ "$jobs_to_run" -eq 0 ]; then
		message+='There are no jobs to run!'
	else
		message+="There $(plur_sing $jobs_to_run are is) $jobs_to_run"
		message+=" job$(plur_sing $jobs_to_run)."
		message+=$'\n'
		message+="Run $(plur_sing $jobs_to_run them it)?"
	fi
	[ "$failed_jobs" -gt 0 ] && {
		message+=$'\n\n\n'
		[ "$jobs_to_run" -eq 0 ]  \
			&& message+="(But there $(plur_sing $failed_jobs are is) $failed_jobs"  \
			|| message+="(There $(plur_sing $failed_jobs are is) also $failed_jobs"
		message+=" failed job$(plur_sing $failed_jobs),"
		message+=$'\n'
		message+="that await$(plur_sing $failed_jobs '' s) your attention.)"
	}
	edit_attr_in_xml 'entire_xml' \
	                 "//object[@id='label_there_are_N_jobs']/property[@name='label']" \
	                 "$message"
	#  Buttons
	if [ "$jobs_to_run" -eq 0 ]; then
		run_job_button_text='OK'
		delete_entity_in_xml 'entire_xml' \
		                     "//child[child::object[@id='but_launch_jobs_cancel']]"
		edit_attr_in_xml 'entire_xml' \
		                 "//object[@id='but_launch_jobs_ok1']/property[@name='image']" \
		                 'img_ok_no_jobs'
		edit_attr_in_xml 'entire_xml' \
		                 "//object[@id='butbox_runjobs']/property[@name='margin_top']" \
		                 '6'
		edit_attr_in_xml 'entire_xml' \
		                 "//object[@id='butbox_runjobs']/property[@name='margin_bottom']" \
		                 '6'
	elif [ "$jobs_to_run" -eq 1 ]; then
		run_job_button_text='Run job'
	else
		run_job_button_text='Run jobs'
	fi
	edit_attr_in_xml 'entire_xml' \
	                 "//object[@id='but_launch_jobs_ok1']/property[@name='label']" \
	                 "$run_job_button_text"
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


#  $1 – number of jobs, that are postponed.
show_dialogue_launch_jobs() {
	declare -g dialog_output
	local dialog_retval
	prepare_dotglade_for_launch_jobs "$@"
	set +e
	dialog_output=$( "$py_file"  startpage=gtkbox_launch_jobs )
	dialog_retval=$?
	set -e
	info "Dialog output: “$dialog_output”"
	check_pyfile_exit_code $dialog_retval
	return 0
}


return 0
