#!/usr/bin/env bash
# LinuxGSM fix_ro.sh function
# Author: Daniel Gibbs
# Website: https://linuxgsm.com
# Description: Resolves various issues with Red Orchestra.

local commandname="FIX"
local commandaction="Fix"
local function_selfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

echo "Applying WebAdmin ROOst.css fix."
echo "http://forums.tripwireinteractive.com/showpost.php?p=585435&postcount=13"
sed -i 's/none}/none;/g' "${serverfiles}/Web/ServerAdmin/ROOst.css"
sed -i 's/underline}/underline;/g' "${serverfiles}/Web/ServerAdmin/ROOst.css"
fn_sleep_time
echo "Applying WebAdmin CharSet fix."
echo "http://forums.tripwireinteractive.com/showpost.php?p=442340&postcount=1"
sed -i 's/CharSet="iso-8859-1"/CharSet="utf-8"/g' "${systemdir}/uweb.int"
fn_sleep_time
echo "Applying Steam AppID fix."
sed -i 's/1210/1200/g' "${systemdir}/steam_appid.txt"
fn_sleep_time
echo "applying server name fix."
fn_sleep_time
echo "forcing server restart..."
fn_sleep_time
exitbypass=1
command_start.sh
sleep 5
exitbypass=1
command_stop.sh
exitbypass=1
command_start.sh
sleep 5
exitbypass=1
command_stop.sh
