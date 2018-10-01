#! /usr/bin/env bash

MYDIR="/home/dtr/repos/Nadeshiko/"
TMPDIR=/tmp/tr
[ -d "$TMPDIR" ] || mkdir "$TMPDIR"
rm -rf "$TMPDIR"/*
. ../modules/nadeshiko-mpv_dialogues_gtk.sh

errexit_off() { : dummy; }
errexit_on() { : dummy; }
write_var_to_datafile() {
	local varname="$1" value="$2"
	declare -g $varname
	declare -gn varval="$varname"
	varval="$value"
}
err() { : dummy; }
abort() { : dummy; }


dialog_socket_list=(
	socket1_tag socket1_label on
	socket2_tag socket2_label off
	socket3_tag socket3_label off
	socket4_tag socket4_label off
)

dialog_configs_list=(
	config_1_tag   config1.rc.sh    on
	config_2_tag   config2.rc.sh    off
	config_3_tag   config3.rc.sh    off
	config_4_tag   config4.rc.sh    off
	config_5_tag   config5.rc.sh    off
	config_6_tag   config6.rc.sh    off
	config_7_tag   config7.rc.sh    off
	config_8_tag   config8.rc.sh    off
)

variants=(
	normal "20 MiB" off
	small  "10 MiB" off
	tiny   "2 MiB" on
	unlimited "unlimited – default" off
)

show_dialogue_choose_mpv_socket_gtk
echo "$mpv_config"

show_dialogue_choose_config_file_gtk
echo "$nadeshiko_config"

show_dialogue_pick_size_gtk
echo "$max_size"
echo "$fname_pfx"
echo "$postpone"
