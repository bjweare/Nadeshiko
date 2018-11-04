#! /usr/bin/env bash

set -feEuT

MYDIR="/home/dtr/repos/Nadeshiko/"
TMPDIR=/tmp/tr
[ -d "$TMPDIR" ] || mkdir "$TMPDIR"
rm -rf "$TMPDIR"/*
. ../lib/xml_and_python_functions.sh
. ../modules/nadeshiko-mpv_dialogues_gtk.sh

errexit_off() { : dummy; }
errexit_on() { : dummy; }
write_var_to_datafile() {
	local varname="$1" value="$2"
	declare -g $varname
	declare -gn varval="$varname"
	varval="$value"
}
err() { echo "$1"; exit 5; }
abort() { echo "$1"; exit 7; }


dialog_socket_list=(
	socket1_tag socket1_label on
	socket2_tag socket2_label off
	socket3_tag socket3_label off
	socket4_tag socket4_label off
)

arr2=(
	default_config.rc.sh "default"  "<span weight=\"bold\">Config description</span>"  "Source file desc."
	unlimited	"unlimited – default"	off		=	'1080p'
	normal		"20 MiB"				on		v	'720p*'
	small		"10 MiB"				off		v	'360p'
	tiny		"2 MiB"					off		x	'Won’t fit'
)

arr3=(
	another_config.rc.sh "another" "<span style=\"italic\">Config description</span>"  "Source file desc."
	gehi		"gehi – default"	off		=	'1080p'
	awoo		"awoo"				off		v	'720p*'
	keho		"keho"				off		v	'360p'
	awawa		"awawa"				on		x	'Won’t fit'
)

show_dialogue_choose_mpv_socket 'dialog_socket_list'

#show_dialogue_crop_and_predictor 'pick=off' 'has_installer=yes' 'predictor=on'
#show_dialogue_crop_and_predictor 'pick=on' 'predictor=off'
#show_dialogue_crop_and_predictor 'pick=on' 'predictor=off' '100' '200' '300' '400'
#show_dialogue_crop_and_predictor 'pick=off' 'predictor=off' '100' '200' '300' '400'
#show_dialogue_crop_and_predictor 'pick=on' 'predictor=on' '100' '200' '300'

#show_dialogue_cropping 'Some text hjkh fsd kjh jkfsdh '

#show_dialogue_choose_preset arr2 arr3
