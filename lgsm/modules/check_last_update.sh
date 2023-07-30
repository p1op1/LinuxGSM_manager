#!/bin/bash
# LinuxGSM check_last_update.sh module
# Author: Daniel Gibbs
# Contributors: http://linuxgsm.com/contrib
# Website: https://linuxgsm.com
# Description: Checks Lockfile to see when last update happened.
# Will reboot server if instance not rebooted since update.

moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

if [ -f "${lockdir}/${selfname}-last-started.lock" ]; then
	laststart=$(cat "${lockdir}/${selfname}-last-started.lock")
fi
if [ -f last-updated.lock" ]; then
	lastupdate=$(cat last-updated.lock")
fi

check_status.sh
if [ -f last-updated.lock" ] && [ "${status}" != "0" ]; then
	if [ ! -f "${lockdir}/${selfname}-last-started.lock" ] || [ "${laststart}" -lt "${lastupdate}" ]; then
		fn_print_info "${selfname} has not been restarted since last update"
		fn_script_log_info "${selfname} has not been restarted since last update"
		command_restart.sh
		fn_firstcommand_reset
	fi
fi
