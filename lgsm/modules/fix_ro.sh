#!/bin/bash
# LinuxGSM fix_ro.sh module
# Author: Daniel Gibbs
# Contributors: http://linuxgsm.com/contrib
# Website: https://linuxgsm.com
# Description: Resolves issues with Red Orchestra.

moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

echo -e "applying webinterface ROOst.css fix."
echo -e "http://forums.tripwireinteractive.com/showpost.php?p=585435&postcount=13"
sed -i 's/none}/none;/g' "${serverfiles}/Web/ServerAdmin/ROOst.css"
sed -i 's/underline}/underline;/g' "${serverfiles}/Web/ServerAdmin/ROOst.css"
fn_sleep_time
echo -e "applying webinterface CharSet fix."
echo -e "http://forums.tripwireinteractive.com/showpost.php?p=442340&postcount=1"
sed -i 's/CharSet="iso-8859-1"/CharSet="utf-8"/g' "${systemdir}/uweb.int"
fn_sleep_time
echo -e "applying Steam AppID fix."
sed -i 's/1210/1200/g' "${systemdir}/steam_appid.txt"
fn_sleep_time
echo -e "applying server name fix."
fn_sleep_time
echo -e "forcing server restart..."
fn_sleep_time
exitbypass=1
command_start.sh
fn_firstcommand_reset
fn_sleep_time_5
exitbypass=1
command_stop.sh
fn_firstcommand_reset
exitbypass=1
command_start.sh
fn_firstcommand_reset
fn_sleep_time_5
exitbypass=1
command_stop.sh
fn_firstcommand_reset
