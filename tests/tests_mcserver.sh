#!/bin/bash
# Project: Game Server Managers - LinuxGSM
# Author: Daniel Gibbs
# License: MIT License, Copyright (c) 2020 Daniel Gibbs
# Purpose: Travis CI Tests: Minecraft | Linux Game Server Management Script
# Contributors: https://linuxgsm.com/contrib
# Documentation: https://docs.linuxgsm.com
# Website: https://linuxgsm.com

# DO NOT EDIT THIS FILE
# LinuxGSM configuration is no longer edited here
# To update your LinuxGSM config go to:
# lgsm/config-lgsm
# https://docs.linuxgsm.com/configuration/linuxgsm-config

# Debugging
if [ -f ".dev-debug" ]; then
	exec 5>dev-debug.log
	BASH_XTRACEFD="5"
	set -x
fi

version="v20.1.5"
shortname="mc"
gameservername="mcserver"
rootdir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
selfname=$(basename "$(readlink -f "${BASH_SOURCE[0]}")")
lgsmdir="${rootdir}/lgsm"
logdir="${rootdir}/log"
lgsmlogdir="${logdir}/lgsm"
steamcmddir="${HOME}/.steam/steamcmd"
serverfiles="${rootdir}/serverfiles"
functionsdir="${lgsmdir}/functions"
tmpdir="${lgsmdir}/tmp"
datadir="${lgsmdir}/data"
lockdir="${lgsmdir}/lock"
serverlist="${datadir}/serverlist.csv"
serverlistmenu="${datadir}/serverlistmenu.csv"
configdir="${lgsmdir}/config-lgsm"
configdirserver="${configdir}/${gameservername}"
configdirdefault="${lgsmdir}/config-default"
userinput="${1}"

# Allows for testing not on Travis CI
if [ ! -v TRAVIS ]; then
	TRAVIS_BRANCH="develop"
	TRAVIS_BUILD_DIR="${rootdir}"
else
	selfname="travis"
	travistest="1"
fi

## GitHub Branch Select
# Allows for the use of different function files
# from a different repo and/or branch.
githubuser="GameServerManagers"
githubrepo="LinuxGSM"
githubbranch="${TRAVIS_BRANCH}"

# Core function that is required first.
core_functions.sh(){
	functionfile="${FUNCNAME[0]}"
	fn_bootstrap_fetch_file_github "lgsm/functions" "core_functions.sh" "${functionsdir}" "chmodx" "run" "noforcedl" "nomd5"
}

# Bootstrap
# Fetches the core functions required before passed off to core_dl.sh.
fn_bootstrap_fetch_file(){
	remote_fileurl="${1}"
	local_filedir="${2}"
	local_filename="${3}"
	chmodx="${4:-0}"
	run="${5:-0}"
	forcedl="${6:-0}"
	md5="${7:-0}"
	# Download file if missing or download forced.
	if [ ! -f "${local_filedir}/${local_filename}" ]||[ "${forcedl}" == "forcedl" ]; then
		if [ ! -d "${local_filedir}" ]; then
			mkdir -p "${local_filedir}"
		fi

		# If curl exists download file.
		if [ "$(command -v curl 2>/dev/null)" ]; then
			# Trap to remove part downloaded files.
			echo -en "    fetching ${local_filename}...\c"
			curlcmd=$(curl -s --fail -L -o "${local_filedir}/${local_filename}" "${remote_fileurl}" 2>&1)
			local exitcode=$?
			if [ ${exitcode} -ne 0 ]; then
				echo -e "FAIL"
				if [ -f "${lgsmlog}" ]; then
					echo -e "${remote_fileurl}" | tee -a "${lgsmlog}"
					echo -e "${curlcmd}" | tee -a "${lgsmlog}"
				fi
				exit 1
			else
				echo -e "OK"
			fi
		else
			echo -e "[ FAIL ] Curl is not installed"
			exit 1
		fi
		# Make file chmodx if chmodx is set.
		if [ "${chmodx}" == "chmodx" ]; then
			chmod +x "${local_filedir}/${local_filename}"
		fi
	fi

	if [ -f "${local_filedir}/${local_filename}" ]; then
		# Run file if run is set.
		if [ "${run}" == "run" ]; then
			# shellcheck source=/dev/null
			source "${local_filedir}/${local_filename}"
		fi
	fi
}

fn_bootstrap_fetch_file_github(){
	github_file_url_dir="${1}"
	github_file_url_name="${2}"
	githuburl="https://raw.githubusercontent.com/${githubuser}/${githubrepo}/${githubbranch}/${github_file_url_dir}/${github_file_url_name}"

	remote_fileurl="${githuburl}"
	local_filedir="${3}"
	local_filename="${github_file_url_name}"
	chmodx="${4:-0}"
	run="${5:-0}"
	forcedl="${6:-0}"
	md5="${7:-0}"
	# Passes vars to the file download function.
	fn_bootstrap_fetch_file "${remote_fileurl}" "${local_filedir}" "${local_filename}" "${chmodx}" "${run}" "${forcedl}" "${md5}"
}

# Installer menu.

fn_print_center() {
	columns=$(tput cols)
	line="$*"
	printf "%*s\n" $(( (${#line} + columns) / 2)) "${line}"
}

fn_print_horizontal(){
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' "="
}

# Bash menu.
fn_install_menu_bash() {
	local resultvar=$1
	title=$2
	caption=$3
	options=$4
	fn_print_horizontal
	fn_print_center "${title}"
	fn_print_center "${caption}"
	fn_print_horizontal
	menu_options=()
	while read -r line || [[ -n "${line}" ]]; do
		var=$(echo -e "${line}" | awk -F "," '{print $2 " - " $3}')
		menu_options+=( "${var}" )
	done < "${options}"
	menu_options+=( "Cancel" )
	select option in "${menu_options[@]}"; do
		if [ "${option}" ]&&[ "${option}" != "Cancel" ]; then
			eval "$resultvar=\"${option/%\ */}\""
		fi
		break
	done
}

# Whiptail/Dialog menu.
fn_install_menu_whiptail() {
	local menucmd=$1
	local resultvar=$2
	title=$3
	caption=$4
	options=$5
	height=${6:-40}
	width=${7:-80}
	menuheight=${8:-30}
	IFS=","
	menu_options=()
	while read -r line; do
		key=$(echo -e "${line}" | awk -F "," '{print $3}')
		val=$(echo -e "${line}" | awk -F "," '{print $2}')
		menu_options+=( "${val//\"}" "${key//\"}" )
	done < "${options}"
	OPTION=$(${menucmd} --title "${title}" --menu "${caption}" "${height}" "${width}" "${menuheight}" "${menu_options[@]}" 3>&1 1>&2 2>&3)
	if [ $? == 0 ]; then
		eval "$resultvar=\"${OPTION}\""
	else
		eval "$resultvar="
	fi
}

# Menu selector.
fn_install_menu() {
	local resultvar=$1
	local selection=""
	title=$2
	caption=$3
	options=$4
	# Get menu command.
	for menucmd in whiptail dialog bash; do
		if [ "$(command -v "${menucmd}")" ]; then
			menucmd=$(command -v "${menucmd}")
			break
		fi
	done
	case "$(basename "${menucmd}")" in
		whiptail|dialog)
			fn_install_menu_whiptail "${menucmd}" selection "${title}" "${caption}" "${options}" 40 80 30;;
		*)
			fn_install_menu_bash selection "${title}" "${caption}" "${options}";;
	esac
	eval "$resultvar=\"${selection}\""
}

# Gets server info from serverlist.csv and puts in to array.
fn_server_info(){
	IFS=","
	server_info_array=($(grep -aw "${userinput}" "${serverlist}"))
	shortname="${server_info_array[0]}" # csgo
	gameservername="${server_info_array[1]}" # csgoserver
	gamename="${server_info_array[2]}" # Counter Strike: Global Offensive
}

fn_install_getopt(){
	userinput="empty"
	echo -e "Usage: $0 [option]"
	echo -e ""
	echo -e "Installer - Linux Game Server Managers - Version ${version}"
	echo -e "https://linuxgsm.com"
	echo -e ""
	echo -e "Commands"
	echo -e "install\t\t| Select server to install."
	echo -e "servername\t| Enter name of game server to install. e.g $0 csgoserver."
	echo -e "list\t\t| List all servers available for install."
	exit
}

fn_install_file(){
	local_filename="${gameservername}"
	if [ -e "${local_filename}" ]; then
		i=2
	while [ -e "${local_filename}-${i}" ] ; do
		let i++
	done
		local_filename="${local_filename}-${i}"
	fi
	cp -R "${selfname}" "${local_filename}"
	sed -i -e "s/shortname=\"core\"/shortname=\"${shortname}\"/g" "${local_filename}"
	sed -i -e "s/gameservername=\"core\"/gameservername=\"${gameservername}\"/g" "${local_filename}"
	echo -e "Installed ${gamename} server as ${local_filename}"
	echo -e ""
	if [ ! -d "${serverfiles}" ]; then
		echo -e "./${local_filename} install"
	else
		echo -e "Remember to check server ports"
		echo -e "./${local_filename} details"
	fi
	echo -e ""
	exit
}

# Prevent LinuxGSM from running as root. Except if doing a dependency install.
if [ "$(whoami)" == "root" ]; then
	if [ "${userinput}" == "install" ]||[ "${userinput}" == "auto-install" ]||[ "${userinput}" == "i" ]||[ "${userinput}" == "ai" ]; then
		if [ "${shortname}" == "core" ]; then
			echo -e "[ FAIL ] Do NOT run this script as root!"
			exit 1
		fi
	elif [ ! -f "${functionsdir}/core_functions.sh" ]||[ ! -f "${functionsdir}/check_root.sh" ]||[ ! -f "${functionsdir}/core_messages.sh" ]; then
		echo -e "[ FAIL ] Do NOT run this script as root!"
		exit 1
	else
		core_functions.sh
		check_root.sh
	fi
fi

# LinuxGSM installer mode.
if [ "${shortname}" == "core" ]; then
	# Download the latest serverlist. This is the complete list of all supported servers.
	fn_bootstrap_fetch_file_github "lgsm/data" "serverlist.csv" "${datadir}" "nochmodx" "norun" "forcedl" "nomd5"
	if [ ! -f "${serverlist}" ]; then
		echo -e "[ FAIL ] serverlist.csv could not be loaded."
		exit 1
	fi

	if [ "${userinput}" == "list" ]||[ "${userinput}" == "l" ]; then
		{
			tail -n +2 "${serverlist}" | awk -F "," '{print $2 "\t" $3}'
		} | column -s $'\t' -t | more
		exit
	elif [ "${userinput}" == "install" ]||[ "${userinput}" == "i" ]; then
		tail -n +2 "${serverlist}" | awk -F "," '{print $1 "," $2 "," $3}' > "${serverlistmenu}"
		fn_install_menu result "LinuxGSM" "Select game server to install." "${serverlistmenu}"
		userinput="${result}"
		fn_server_info
		if [ "${result}" == "${gameservername}" ]; then
			fn_install_file
		elif [ "${result}" == "" ]; then
			echo -e "Install canceled"
		else
			echo -e "[ FAIL ] menu result does not match gameservername"
			echo -e "result: ${result}"
			echo -e "gameservername: ${gameservername}"
		fi
	elif [ "${userinput}" ]; then
		fn_server_info
		if [ "${userinput}" == "${gameservername}" ]||[ "${userinput}" == "${gamename}" ]||[ "${userinput}" == "${shortname}" ]; then
			fn_install_file
		else
			echo -e "[ FAIL ] unknown game server"
		fi
	else
		fn_install_getopt
	fi

# LinuxGSM server mode.
else
	core_functions.sh
	if [ "${shortname}" != "core-dep" ]; then
		# Load LinuxGSM configs.
		# These are required to get all the default variables for the specific server.
		# Load the default config. If missing download it. If changed reload it.
		if [ ! -f "${configdirdefault}/config-lgsm/${gameservername}/_default.cfg" ]; then
			mkdir -p "${configdirdefault}/config-lgsm/${gameservername}"
			fn_fetch_config "lgsm/config-default/config-lgsm/${gameservername}" "_default.cfg" "${configdirdefault}/config-lgsm/${gameservername}" "_default.cfg" "nochmodx" "norun" "noforcedl" "nomd5"
		fi
		if [ ! -f "${configdirserver}/_default.cfg" ]; then
			mkdir -p "${configdirserver}"
			echo -en "    copying _default.cfg...\c"
			cp -R "${configdirdefault}/config-lgsm/${gameservername}/_default.cfg" "${configdirserver}/_default.cfg"
			exitcode=$?
			if [ ${exitcode} -ne 0 ]; then
				echo -e "FAIL"
				exit 1
			else
				echo -e "OK"
			fi
		else
			function_file_diff=$(diff -q "${configdirdefault}/config-lgsm/${gameservername}/_default.cfg" "${configdirserver}/_default.cfg")
			if [ "${function_file_diff}" != "" ]; then
				fn_print_warn_nl "_default.cfg has been altered. reloading config."
				echo -en "    copying _default.cfg...\c"
				cp -R "${configdirdefault}/config-lgsm/${gameservername}/_default.cfg" "${configdirserver}/_default.cfg"
				exitcode=$?
				if [ ${exitcode} -ne 0 ]; then
					echo -e "FAIL"
					exit 1
				else
					echo -e "OK"
				fi
			fi
		fi
		source "${configdirserver}/_default.cfg"
		# Load the common.cfg config. If missing download it.
		if [ ! -f "${configdirserver}/common.cfg" ]; then
			fn_fetch_config "lgsm/config-default/config-lgsm" "common-template.cfg" "${configdirserver}" "common.cfg" "${chmodx}" "nochmodx" "norun" "noforcedl" "nomd5"
			source "${configdirserver}/common.cfg"
		else
			source "${configdirserver}/common.cfg"
		fi
		# Load the instance.cfg config. If missing download it.
		if [ ! -f "${configdirserver}/${selfname}.cfg" ]; then
			fn_fetch_config "lgsm/config-default/config-lgsm" "instance-template.cfg" "${configdirserver}" "${selfname}.cfg" "nochmodx" "norun" "noforcedl" "nomd5"
			source "${configdirserver}/${selfname}.cfg"
		else
			source "${configdirserver}/${selfname}.cfg"
		fi

		# Load the linuxgsm.sh in to tmpdir. If missing download it.
		if [ ! -f "${tmpdir}/linuxgsm.sh" ]; then
			fn_fetch_file_github "" "linuxgsm.sh" "${tmpdir}" "chmodx" "norun" "noforcedl" "nomd5"
		fi
	fi
	# Enables ANSI colours from core_messages.sh. Can be disabled with ansi=off.
	fn_ansi_loader
	# Prevents running of core_exit.sh for Travis-CI.
	if [ -z "${travistest}" ]; then
		getopt=$1
		core_getopt.sh
	fi
fi

fn_currentstatus_tmux(){
	check_status.sh
	if [ "${status}" != "0" ]; then
		currentstatus="ONLINE"
	else
		currentstatus="OFFLINE"
	fi
}

fn_currentstatus_ts3(){
	check_status.sh
	if [ "${status}" != "0" ]; then
		currentstatus="ONLINE"
	else
		currentstatus="OFFLINE"
	fi
}

fn_setstatus(){
	fn_currentstatus_tmux
	echo""
	echo -e "Required status: ${requiredstatus}"
	counter=0
	echo -e "Current status:  ${currentstatus}"
	while [  "${requiredstatus}" != "${currentstatus}" ]; do
		counter=$((counter+1))
		fn_currentstatus_tmux
		echo -en "New status:  ${currentstatus}\\r"

		if [ "${requiredstatus}" == "ONLINE" ]; then
			(command_start.sh > /dev/null 2>&1)
		else
			(command_stop.sh > /dev/null 2>&1)
		fi
		if [ "${counter}" -gt "5" ]; then
			currentstatus="FAIL"
			echo -e "Current status:  ${currentstatus}"
			echo -e ""
			echo -e "Unable to start or stop server."
			exit 1
		fi
	done
	echo -en "New status:  ${currentstatus}\\r"
	echo -e "\n"
	echo -e "Test starting:"
	echo -e ""
}

# End of every test will expect the result to either pass or fail
# If the script does not do as intended the whole test will fail
# if expecting a pass
fn_test_result_pass(){
	if [ $? != 0 ]; then
		echo -e "================================="
		echo -e "Expected result: PASS"
		echo -e "Actual result: FAIL"
		fn_print_fail_nl "TEST FAILED"
		exitcode=1
		core_exit.sh
	else
		echo -e "================================="
		echo -e "Expected result: PASS"
		echo -e "Actual result: PASS"
		fn_print_ok_nl "TEST PASSED"
		echo -e ""
	fi
}

# if expecting a fail
fn_test_result_fail(){
	if [ $? == 0 ]; then
		echo -e "================================="
		echo -e "Expected result: FAIL"
		echo -e "Actual result: PASS"
		fn_print_fail_nl "TEST FAILED"
		exitcode=1
		core_exit.sh
	else
		echo -e "================================="
		echo -e "Expected result: FAIL"
		echo -e "Actual result: FAIL"
		fn_print_ok_nl "TEST PASSED"
		echo -e ""
	fi
}

# test result n/a
fn_test_result_na(){
	echo -e "================================="
	echo -e "Expected result: N/A"
	echo -e "Actual result: N/A"
	fn_print_fail_nl "TEST N/A"
}

sleeptime="0"

echo -e "================================="
echo -e "Travis CI Tests"
echo -e "Linux Game Server Manager"
echo -e "by Daniel Gibbs"
echo -e "Contributors: http://goo.gl/qLmitD"
echo -e "https://linuxgsm.com"
echo -e "================================="
echo -e ""
echo -e "================================="
echo -e "Server Tests"
echo -e "Using: ${gamename}"
echo -e "Testing Branch: $TRAVIS_BRANCH"
echo -e "================================="

echo -e ""
echo -e "0.0 - Pre-test Tasks"
echo -e "=================================================================="
echo -e "Description:"
echo -e "Create log dir's"
echo -e ""

echo -e ""
echo -e "0.1 - Create log dir's"
echo -e "================================="
echo -e ""
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	install_logs.sh
)
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "0.2 - Enable dev-debug"
echo -e "================================="
echo -e "Description:"
echo -e "Enable dev-debug"
echo -e ""
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_dev_debug.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "1.0 - Pre-install tests"
echo -e "=================================================================="
echo -e ""

echo -e "1.1 - start - no files"
echo -e "================================="
echo -e "Description:"
echo -e "test script reaction to missing server files."
echo -e "Command: ./${gameservername} start"
echo -e ""
# Allows for testing not on Travis CI
if [ ! -v TRAVIS ]; then
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_start.sh
)
fn_test_result_fail
else
	echo -e "Test bypassed"
fi

echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "1.2 - getopt"
echo -e "================================="
echo -e "Description:"
echo -e "displaying options messages."
echo -e "Command: ./${gameservername}"
echo -e ""
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	core_getopt.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "1.3 - getopt with incorrect args"
echo -e "================================="
echo -e "Description:"
echo -e "displaying options messages."
echo -e "Command: ./${gameservername} abc123"
echo -e ""
getopt="abc123"
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	core_getopt.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "2.0 - Installation"
echo -e "=================================================================="

echo -e ""
echo -e "2.0 - install"
echo -e "================================="
echo -e "Description:"
echo -e "install ${gamename} server."
echo -e "Command: ./${gameservername} auto-install"
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	fn_autoinstall
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "3.0 - Start/Stop/Restart Tests"
echo -e "=================================================================="

echo -e ""
echo -e "3.1 - start"
echo -e "================================="
echo -e "Description:"
echo -e "start ${gamename} server."
echo -e "Command: ./${gameservername} start"
requiredstatus="OFFLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_start.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "3.2 - start - online"
echo -e "================================="
echo -e "Description:"
echo -e "start ${gamename} server while already running."
echo -e "Command: ./${gameservername} start"
requiredstatus="ONLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_start.sh
)
fn_test_result_fail
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "3.3 - start - updateonstart"
echo -e "================================="
echo -e "Description:"
echo -e "will update server on start."
echo -e "Command: ./${gameservername} start"
requiredstatus="OFFLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	updateonstart="on";command_start.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'
echo -e ""
echo -e "30s Pause"
echo -e "================================="
echo -e "Description:"
echo -e "give time for server to fully start."
echo -e "Command: sleep 30"
requiredstatus="ONLINE"
fn_setstatus
sleep 30

echo -e ""
echo -e "3.4 - stop"
echo -e "================================="
echo -e "Description:"
echo -e "stop ${gamename} server."
echo -e "Command: ./${gameservername} stop"
requiredstatus="ONLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_stop.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "3.5 - stop - offline"
echo -e "================================="
echo -e "Description:"
echo -e "stop ${gamename} server while already stopped."
echo -e "Command: ./${gameservername} stop"
requiredstatus="OFFLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_stop.sh
)
fn_test_result_fail
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "3.6 - restart"
echo -e "================================="
echo -e "Description:"
echo -e "restart ${gamename}."
echo -e "Command: ./${gameservername} restart"
requiredstatus="ONLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_restart.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "3.7 - restart - offline"
echo -e "================================="
echo -e "Description:"
echo -e "restart ${gamename} while already stopped."
echo -e "Command: ./${gameservername} restart"
requiredstatus="OFFLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_restart.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "4.0 - Update Tests"
echo -e "=================================================================="

echo -e ""
echo -e "4.1 - update"
echo -e "================================="
echo -e "Description:"
echo -e "check for updates."
echo -e "Command: ./${gameservername} update"
requiredstatus="OFFLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_update.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "Inserting IP address"
echo -e "================================="
echo -e "Description:"
echo -e "Inserting Travis IP in to config."
echo -e "Allows monitor to work"
if [ "$(ip -o -4 addr|grep eth0)" ]; then
	travisip=$(ip -o -4 addr | grep eth0 | awk '{print $4}' | grep -oe '\([0-9]\{1,3\}\.\?\)\{4\}' | grep -v 127.0.0)
else
	travisip=$(ip -o -4 addr | grep ens | awk '{print $4}' | grep -oe '\([0-9]\{1,3\}\.\?\)\{4\}' | sort -u | grep -v 127.0.0)
fi
sed -i "/server-ip=/c\server-ip=${travisip}" "${serverfiles}/server.properties"
echo -e "IP: ${travisip}"

echo -e ""
echo -e "5.0 - Monitor Tests"
echo -e "=================================================================="
echo -e ""
echo -e "Server IP - Port: ${ip}:${port}"
echo -e "Server IP - Query Port: ${ip}:${queryport}"

echo -e ""
echo -e "30s Pause"
echo -e "================================="
echo -e "Description:"
echo -e "give time for server to fully start."
echo -e "Command: sleep 30"
requiredstatus="ONLINE"
fn_setstatus
sleep 30

echo -e ""
echo -e "5.1 - monitor - online"
echo -e "================================="
echo -e "Description:"
echo -e "run monitor server while already running."
echo -e "Command: ./${gameservername} monitor"
requiredstatus="ONLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_monitor.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "5.2 - monitor - offline - with lockfile"
echo -e "================================="
echo -e "Description:"
echo -e "run monitor while server is offline with lockfile."
echo -e "Command: ./${gameservername} monitor"
requiredstatus="OFFLINE"
fn_setstatus
fn_print_info_nl "creating lockfile."
date '+%s' > "${lockdir}/${selfname}.lock"
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_monitor.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "5.3 - monitor - offline - no lockfile"
echo -e "================================="
echo -e "Description:"
echo -e "run monitor while server is offline with no lockfile."
echo -e "Command: ./${gameservername} monitor"
requiredstatus="OFFLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_monitor.sh
)
fn_test_result_fail
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "5.4 - test-alert"
echo -e "================================="
echo -e "Description:"
echo -e "run monitor while server is offline with no lockfile."
echo -e "Command: ./${gameservername} test-alert"
requiredstatus="OFFLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_test_alert.sh
)
fn_test_result_fail
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "6.0 - Details Tests"
echo -e "=================================================================="

echo -e ""
echo -e "6.1 - details"
echo -e "================================="
echo -e "Description:"
echo -e "display details."
echo -e "Command: ./${gameservername} details"
requiredstatus="ONLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_details.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "6.2 - postdetails"
echo -e "================================="
echo -e "Description:"
echo -e "post details."
echo -e "Command: ./${gameservername} postdetails"
requiredstatus="ONLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_postdetails.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "7.0 - Backup Tests"
echo -e "=================================================================="

echo -e ""
echo -e "7.1 - backup"
echo -e "================================="
echo -e "Description:"
echo -e "run a backup."
echo -e "Command: ./${gameservername} backup"
requiredstatus="ONLINE"
fn_setstatus
echo -e "test de-activated until issue #1839 fixed"
#(command_backup.sh)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "8.0 - Development Tools Tests"
echo -e "=================================================================="

echo -e ""
echo -e "8.1 - dev - detect glibc"
echo -e "================================="
echo -e "Description:"
echo -e "detect glibc."
echo -e "Command: ./${gameservername} detect-glibc"
requiredstatus="ONLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_dev_detect_glibc.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "8.2 - dev - detect ldd"
echo -e "================================="
echo -e "Description:"
echo -e "detect ldd."
echo -e "Command: ./${gameservername} detect-ldd"
requiredstatus="ONLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_dev_detect_ldd.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "8.3 - dev - detect deps"
echo -e "================================="
echo -e "Description:"
echo -e "detect dependencies."
echo -e "Command: ./${gameservername} detect-deps"
requiredstatus="ONLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_dev_detect_deps.sh
)
fn_test_result_pass
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "Inserting IP address"
echo -e "================================="
echo -e "Description:"
echo -e "Inserting Travis IP in to config."
echo -e "Allows monitor to work"
if [ "$(ip -o -4 addr|grep eth0)" ]; then
	travisip=$(ip -o -4 addr | grep eth0 | awk '{print $4}' | grep -oe '\([0-9]\{1,3\}\.\?\)\{4\}' | grep -v 127.0.0)
else
	travisip=$(ip -o -4 addr | grep ens | awk '{print $4}' | grep -oe '\([0-9]\{1,3\}\.\?\)\{4\}' | sort -u | grep -v 127.0.0)
fi
sed -i "/server-ip=/c\server-ip=${travisip}" "${serverfiles}/server.properties"
echo -e "IP: ${travisip}"

echo -e ""
echo -e "8.4 - dev - query-raw"
echo -e "================================="
echo -e "Description:"
echo -e "raw query output."
echo -e "Command: ./${gameservername} query-raw"
requiredstatus="ONLINE"
fn_setstatus
(
	exec 5>"${TRAVIS_BUILD_DIR}/dev-debug.log"
	BASH_XTRACEFD="5"
	set -x
	command_dev_query_raw.sh
)
fn_test_result_na
echo -e "run order"
echo -e "================="
grep functionfile= "${TRAVIS_BUILD_DIR}/dev-debug.log" | sed 's/functionfile=//g'

echo -e ""
echo -e "================================="
echo -e "Server Tests - Complete!"
echo -e "Using: ${gamename}"
echo -e "================================="
requiredstatus="OFFLINE"
fn_setstatus
if [ ! -v TRAVIS ]; then
	fn_print_info "Tidying up directories."
	rm -rfv "${serverfiles:?}"
fi
core_exit.sh
