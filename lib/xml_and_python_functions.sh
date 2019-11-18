#  Should be sourced.

#  xml_and_python_functions.sh
#  Helper functions to parse and generate code in Glade XML and Python script
#  accompanying it.
#  © deterenkelt 2018–2019
#
#  For licence see nadeshiko.sh


#  In the code below, $xml should point to xmlstarlet binary.


 # Cuts a part of XML from the value of one variable and assignes to another.
#  $1 – name of the variable with XML source.
#  $2 – xpath to extract.
#  $3 – name of the variable, to which the chunk of XML should be assigned.
#
put_xml_chunk_in_var() {
	local    source_varname="$1"
	local    xpath="$2"
	local    dest_varname="$3"
	local -n source_varval="$source_varname"
	local -n dest_varval="$dest_varname"

	dest_varval=$(	$xml sel -t -c "$xpath"  <<<"$source_varval" )

	return 0
}


 # Updates value in an attribute (attr="val") or the contents of a tag.
#  This function should be used to edit attribute and tag values, where
#    possible, because add_obj_property_to_xml() uses 4× more calls to $xml.
#  $1 – name of the variable, XML in which should be edited.
#  $2 – xpath to edit. /prop/@id will replace value of id in <prop> tag,
#                      /prop will replace contents between <prop> and </prop>.
#  $3 – value to set.
#
edit_attr_in_xml() {
	local    varname="$1"
	local    xpath="$2"
	local    value="$3"
	local    xmlbuf
	local -n varval="$varname"

	xmlbuf="$varval"
	varval=$( $xml ed -O  -u "$xpath"  -v "$value"  <<<"$xmlbuf" )

	return 0
}


 # Deletes an entity (or subtree) from XML.
#  $1 – name of the variable, XML in which should be deleted.
#  $2 – xpath to delete.
#
delete_entity_in_xml() {
	local    varname="$1"
	local    xpath="$2"
	local    xmlbuf
	local -n varval="$varname"

	xmlbuf="$varval"
	varval=$( $xml ed -O  -d "$xpath"  <<<"$xmlbuf" )

	return 0
}


 # Places XML from one variable to XML in another variable by xpath.
#  $1 – name of the variable with source XML.
#  $2 – xpath where new XML is to be inserted.
#  $3 – XML to insert.
#
insert_one_xml_into_another() {
	local    varname="$1"
	local    xpath="$2"
	local    xml_to_insert="$3"
	local    xmlbuf
	local -n varval="$varname"

	#  Put a mark in the XML, that sed will replace with new XML.
	xmlbuf="$varval"
	varval=$( $xml ed -O  -s "$xpath"  -t elem  -n "puthere"  <<<"$xmlbuf" )
	#  Replace the mark with new XML
	xmlbuf="$varval"
	echo "$xml_to_insert"  >"$TMPDIR/xml_to_insert"
	varval=$(
		sed -r "/^\s*<puthere\/>\s*$/ {
		                                s/.*//
		                                r $TMPDIR/xml_to_insert
		                              }"  \
		       <<<"$xmlbuf"
	)

	return 0
}


 # Inserts generated code into .py file, in place of ###  PLACEHOLDERS  ###.
#  $1 – name of the variable, that contains entire code.
#  $2 – name of the variable, that holds an associative array, where keys
#       are placeholder patters and values are code to substitute them.
#       A placeholder pattern is any text between “### PLACEHOLDER” and “###”.
#
insert_blocks_in_py_code() {
	local    entire_code_varname="$1"
	local    ph_and_ins_code_varname="$2"
	local    entire_code
	local    entire_code_buf
	local    ph_and_ins_code
	local    key
	local    ph_text
	local    pycode_to_insert
	local -n entire_code="$entire_code_varname"
	local -n ph_and_ins_code="$ph_and_ins_code_varname"

	for key in "${!ph_and_ins_code[@]}"; do
		ph_text="$key"
		pycode_to_insert="${ph_and_ins_code[$key]}"
		ph_text=${ph_text//\*/\\\*}
		echo "$pycode_to_insert"  >"$TMPDIR/pycode_to_insert"
		entire_code_buf="$entire_code"
		entire_code="$(
			sed -r "/^\s*###\s.*$ph_text.*\s+###.*$/ {
				                                       s/.*//
				                                       r $TMPDIR/pycode_to_insert
			                                         }"  \
				<<<"$entire_code_buf"
		)"
	done

	return 0
}


 # Creates a new <property></property> element for an object, sets its “name”
#    attribute and assigns value between <property> and </property>. If the
#    tag would exist in the tree, it will be deleted beforehand.
#  This function should be preferred over edit_attr_in_xml() in cases, when
#    the last entity in $xpath may or may not exist – edit_attr_in_xml() will
#    fail, if it would be to edit a non-existing tag.
#  $1 – name of the variable, that holds source XML.
#  $2 – xpath to an object, in which <property> tag must be added.
#  $3 – attribute name.
#  $4 – tag value.
#
add_obj_property_to_xml() {
	local    varname="$1"
	local    xpath="$2"
	local    attr="$3"
	local    value="$4"
	local    xmlbuf
	local -n varval="$varname"

	#  First, delete property with specified attribute, if it exists.
	xmlbuf="$varval"
	varval=$( $xml ed -O  -d "$xpath/property[@name='$attr']"  <<<"$xmlbuf" )
	#  Now create a new property.
	xmlbuf="$varval"
	varval=$(
		$xml ed -O -s "$xpath" -t elem  -n 'property'  -v '~!~'  <<<"$xmlbuf" \
			| $xml ed -O  -i "$xpath/property[text()='~!~']" \
			             -t attr  -n 'name'  -v "$attr"  \
			| $xml ed -O  -u "$xpath/property[@name='$attr']"  -v "$value"
	)

	return 0
}


 # Do finishing checks and path replacements in .glade and .py files.
#  This will also drop the contents of $entire_xml to $glade_file.
#
write_dotglade_and_dotpy_files() {
	local first_line

	#  Check, that entire_xml has proper XML header
	read first_line <<<"$entire_xml"
	[[ "$first_line" =~ ^\<\?xml[[:space:]]version ]] || {
		entire_xml='<?xml version="1.0" encoding="UTF-8"?>'$'\n'"$entire_xml"
	}
	echo "$entire_xml"  >"$glade_file"
	echo "$entire_py_code"  >"$py_file"
	sed -ri "s~(\s*builder\.add_from_file\(').*('\)\s*)~\1$glade_file\2~"  \
	        "$py_file"
	#  Update icon path too. (Add MY_RES_PATH? MY_ICON_PATH?)

	return 0
}


return 0