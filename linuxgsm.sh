#!/bin/bash
# Project: Linux Game Server Managers - LinuxGSM
# Author: Daniel Gibbs
# License: MIT License, see LICENSE.md
# Purpose: Linux Game Server Management Script
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
	exec 5> dev-debug.log
	BASH_XTRACEFD="5"
	set -x
fi

version="v23.3.1"
shortname="core"
gameservername="core"
commandname="CORE"
rootdir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
selfname=$(basename "$(readlink -f "${BASH_SOURCE[0]}")")
sessionname=$(echo "${selfname}" | cut -f1 -d".")
lgsmdir="${rootdir}/lgsm"
logdir="${rootdir}/log"
lgsmlogdir="${logdir}/lgsm"
steamcmddir="${HOME}/.steam/steamcmd"
serverfiles="${rootdir}/serverfiles"
modulesdir="${lgsmdir}/modules"
tmpdir="${lgsmdir}/tmp"
datadir="${lgsmdir}/data"
lockdir="${lgsmdir}/lock"
serverlist="${datadir}/serverlist.csv"
serverlistmenu="${datadir}/serverlistmenu.csv"
configdir="${lgsmdir}/config-lgsm"
configdirserver="${configdir}/${gameservername}"
configdirdefault="${lgsmdir}/config-default"
userinput="${1}"
userinput2="${2}"

## GitHub Branch Select
# Allows for the use of different function files
# from a different repo and/or branch.
[ -n "${LGSM_GITHUBUSER}" ] && githubuser="${LGSM_GITHUBUSER}" || githubuser="GameServerManagers"
[ -n "${LGSM_GITHUBREPO}" ] && githubrepo="${LGSM_GITHUBREPO}" || githubrepo="LinuxGSM"
[ -n "${LGSM_GITHUBBRANCH}" ] && githubbranch="${LGSM_GITHUBBRANCH}" || githubbranch="master"

# Check that curl is installed before doing anything
if [ ! "$(command -v curl 2> /dev/null)" ]; then
	echo -e "[ FAIL ] Curl is not installed"
	exit 1
fi

# Core module that is required first.
core_modules.sh() {
	modulefile="${FUNCNAME[0]}"
	fn_bootstrap_fetch_file_github "lgsm/modules" "core_modules.sh" "${modulesdir}" "chmodx" "run" "noforcedl" "nomd5"
}

# Bootstrap
# Fetches the core modules required before passed off to core_dl.sh.
fn_bootstrap_fetch_file() {
	remote_fileurl="${1}"
	remote_fileurl_backup="${2}"
	remote_fileurl_name="${3}"
	remote_fileurl_backup_name="${4}"
	local_filedir="${5}"
	local_filename="${6}"
	chmodx="${7:-0}"
	run="${8:-0}"
	forcedl="${9:-0}"
	md5="${10:-0}"
	# Download file if missing or download forced.
	if [ ! -f "${local_filedir}/${local_filename}" ] || [ "${forcedl}" == "forcedl" ]; then
		# If backup fileurl exists include it.
		if [ -n "${remote_fileurl_backup}" ]; then
			# counter set to 0 to allow second try
			counter=0
			remote_fileurls_array=(remote_fileurl remote_fileurl_backup)
		else
			# counter set to 1 to not allow second try
			counter=1
			remote_fileurls_array=(remote_fileurl)
		fi

		for remote_fileurl_array in "${remote_fileurls_array[@]}"; do
			if [ "${remote_fileurl_array}" == "remote_fileurl" ]; then
				fileurl="${remote_fileurl}"
				fileurl_name="${remote_fileurl_name}"
			elif [ "${remote_fileurl_array}" == "remote_fileurl_backup" ]; then
				fileurl="${remote_fileurl_backup}"
				fileurl_name="${remote_fileurl_backup_name}"
			fi
			counter=$((counter + 1))
			if [ ! -d "${local_filedir}" ]; then
				mkdir -p "${local_filedir}"
			fi
			# Trap will remove part downloaded files if canceled.
			trap fn_fetch_trap INT
			# Larger files show a progress bar.

			echo -en "fetching ${fileurl_name} ${local_filename}...\c"
			curlcmd=$(curl --connect-timeout 10 -s --fail -L -o "${local_filedir}/${local_filename}" "${fileurl}" 2>&1)

			local exitcode=$?

			# Download will fail if downloads a html file.
			if [ -f "${local_filedir}/${local_filename}" ]; then
				if [ -n "$(head "${local_filedir}/${local_filename}" | grep "DOCTYPE")" ]; then
					rm -f "${local_filedir:?}/${local_filename:?}"
					local exitcode=2
				fi
			fi

			# On first try will error. On second try will fail.
			if [ "${exitcode}" != 0 ]; then
				if [ ${counter} -ge 2 ]; then
					echo -e "FAIL"
					if [ -f "${lgsmlog}" ]; then
						fn_script_log_fatal "Downloading ${local_filename}"
						fn_script_log_fatal "${fileurl}"
					fi
					core_exit.sh
				else
					echo -e "ERROR"
					if [ -f "${lgsmlog}" ]; then
						fn_script_log_error "Downloading ${local_filename}"
						fn_script_log_error "${fileurl}"
					fi
				fi
			else
				echo -en "OK"
				sleep 0.3
				echo -en "\033[2K\\r"
				if [ -f "${lgsmlog}" ]; then
					fn_script_log_pass "Downloading ${local_filename}"
				fi

				# Make file executable if chmodx is set.
				if [ "${chmodx}" == "chmodx" ]; then
					chmod +x "${local_filedir}/${local_filename}"
				fi

				# Remove trap.
				trap - INT

				break
			fi
		done
	fi

	if [ -f "${local_filedir}/${local_filename}" ]; then
		# Execute file if run is set.
		if [ "${run}" == "run" ]; then
			# shellcheck source=/dev/null
			source "${local_filedir}/${local_filename}"
		fi
	fi
}

fn_bootstrap_fetch_file_github() {
	github_file_url_dir="${1}"
	github_file_url_name="${2}"
	# By default modules will be downloaded from the version release to prevent potential version mixing. Only update-lgsm will allow an update.
	if [ "${githubbranch}" == "master" ] && [ "${githubuser}" == "GameServerManagers" ] && [ "${commandname}" != "UPDATE-LGSM" ]; then
		remote_fileurl="https://raw.githubusercontent.com/${githubuser}/${githubrepo}/${version}/${github_file_url_dir}/${github_file_url_name}"
		remote_fileurl_backup="https://bitbucket.org/${githubuser}/${githubrepo}/raw/${version}/${github_file_url_dir}/${github_file_url_name}"
	else
		remote_fileurl="https://raw.githubusercontent.com/${githubuser}/${githubrepo}/${githubbranch}/${github_file_url_dir}/${github_file_url_name}"
		remote_fileurl_backup="https://bitbucket.org/${githubuser}/${githubrepo}/raw/${githubbranch}/${github_file_url_dir}/${github_file_url_name}"
	fi
	remote_fileurl_name="GitHub"
	remote_fileurl_backup_name="Bitbucket"
	local_filedir="${3}"
	local_filename="${github_file_url_name}"
	chmodx="${4:-0}"
	run="${5:-0}"
	forcedl="${6:-0}"
	md5="${7:-0}"
	# Passes vars to the file download module.
	fn_bootstrap_fetch_file "${remote_fileurl}" "${remote_fileurl_backup}" "${remote_fileurl_name}" "${remote_fileurl_backup_name}" "${local_filedir}" "${local_filename}" "${chmodx}" "${run}" "${forcedl}" "${md5}"
}

# Installer menu.

fn_print_center() {
	columns=$(tput cols)
	line="$*"
	printf "%*s\n" $(((${#line} + columns) / 2)) "${line}"
}

fn_print_horizontal() {
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
		menu_options+=("${var}")
	done < "${options}"
	menu_options+=("Cancel")
	select option in "${menu_options[@]}"; do
		if [ "${option}" ] && [ "${option}" != "Cancel" ]; then
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
		menu_options+=("${val//\"/}" "${key//\"/}")
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
		whiptail | dialog)
			fn_install_menu_whiptail "${menucmd}" selection "${title}" "${caption}" "${options}" 40 80 30
			;;
		*)
			fn_install_menu_bash selection "${title}" "${caption}" "${options}"
			;;
	esac
	eval "$resultvar=\"${selection}\""
}

# Gets server info from serverlist.csv and puts in to array.
fn_server_info() {
	IFS=","
	server_info_array=($(grep -aw "${userinput}" "${serverlist}"))
	shortname="${server_info_array[0]}"      # csgo
	gameservername="${server_info_array[1]}" # csgoserver
	gamename="${server_info_array[2]}"       # Counter Strike: Global Offensive
}

fn_install_getopt() {
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

fn_install_file() {
	local_filename="${gameservername}"
	if [ -e "${local_filename}" ]; then
		i=2
		while [ -e "${local_filename}-${i}" ]; do
			((i++))
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
if [ "$(whoami)" == "root" ] && [ ! -f /.dockerenv ]; then
	if [ "${userinput}" == "install" ] || [ "${userinput}" == "auto-install" ] || [ "${userinput}" == "i" ] || [ "${userinput}" == "ai" ]; then
		if [ "${shortname}" == "core" ]; then
			echo -e "[ FAIL ] Do NOT run this script as root!"
			exit 1
		fi
	elif [ ! -f "${modulesdir}/core_modules.sh" ] || [ ! -f "${modulesdir}/check_root.sh" ] || [ ! -f "${modulesdir}/core_messages.sh" ]; then
		echo -e "[ FAIL ] Do NOT run this script as root!"
		exit 1
	else
		core_modules.sh
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

	if [ "${userinput}" == "list" ] || [ "${userinput}" == "l" ]; then
		{
			tail -n +1 "${serverlist}" | awk -F "," '{print $2 "\t" $3}'
		} | column -s $'\t' -t | more
		exit
	elif [ "${userinput}" == "install" ] || [ "${userinput}" == "i" ]; then
		tail -n +1 "${serverlist}" | awk -F "," '{print $1 "," $2 "," $3}' > "${serverlistmenu}"
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
		if [ "${userinput}" == "${gameservername}" ] || [ "${userinput}" == "${gamename}" ] || [ "${userinput}" == "${shortname}" ]; then
			fn_install_file
		else
			echo -e "[ FAIL ] Unknown game server"
			exit 1
		fi
	else
		fn_install_getopt
	fi

# LinuxGSM server mode.
else
	core_modules.sh
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
			echo -en "copying _default.cfg...\c"
			cp -R "${configdirdefault}/config-lgsm/${gameservername}/_default.cfg" "${configdirserver}/_default.cfg"
			if [ $? != 0 ]; then
				echo -e "FAIL"
				exit 1
			else
				echo -e "OK"
			fi
		else
			config_file_diff=$(diff -q "${configdirdefault}/config-lgsm/${gameservername}/_default.cfg" "${configdirserver}/_default.cfg")
			if [ "${config_file_diff}" != "" ]; then
				fn_print_warn_nl "_default.cfg has altered. reloading config."
				echo -en "copying _default.cfg...\c"
				cp -R "${configdirdefault}/config-lgsm/${gameservername}/_default.cfg" "${configdirserver}/_default.cfg"
				if [ $? != 0 ]; then
					echo -e "FAIL"
					exit 1
				else
					echo -e "OK"
				fi
			fi
		fi
	fi
	# Load the IP details before the first config is loaded.
	check_ip.sh
	# Configs have to be loaded twice to allow start startparameters to pick up all vars
	# shellcheck source=/dev/null
	source "${configdirserver}/_default.cfg"
	# Load the common.cfg config. If missing download it.
	if [ ! -f "${configdirserver}/common.cfg" ]; then
		fn_fetch_config "lgsm/config-default/config-lgsm" "common-template.cfg" "${configdirserver}" "common.cfg" "${chmodx}" "nochmodx" "norun" "noforcedl" "nomd5"
		# shellcheck source=/dev/null
		source "${configdirserver}/common.cfg"
	else
		# shellcheck source=/dev/null
		source "${configdirserver}/common.cfg"
	fi
	# Load the secrets-common.cfg config. If missing download it.
	if [ ! -f "${configdirserver}/secrets-common.cfg" ]; then
		fn_fetch_config "lgsm/config-default/config-lgsm" "secrets-common-template.cfg" "${configdirserver}" "secrets-common.cfg" "${chmodx}" "nochmodx" "norun" "noforcedl" "nomd5"
		# shellcheck source=/dev/null
		source "${configdirserver}/secrets-common.cfg"
	else
		# shellcheck source=/dev/null
		source "${configdirserver}/secrets-common.cfg"
	fi
	# Load the instance.cfg config. If missing download it.
	if [ ! -f "${configdirserver}/${selfname}.cfg" ]; then
		fn_fetch_config "lgsm/config-default/config-lgsm" "instance-template.cfg" "${configdirserver}" "${selfname}.cfg" "nochmodx" "norun" "noforcedl" "nomd5"
		# shellcheck source=/dev/null
		source "${configdirserver}/${selfname}.cfg"
	else
		# shellcheck source=/dev/null
		source "${configdirserver}/${selfname}.cfg"
	fi
	# Load the secrets-instance.cfg config. If missing download it.
	if [ ! -f "${configdirserver}/secrets-${selfname}.cfg" ]; then
		fn_fetch_config "lgsm/config-default/config-lgsm" "secrets-instance-template.cfg" "${configdirserver}" "secrets-${selfname}.cfg" "nochmodx" "norun" "noforcedl" "nomd5"
		# shellcheck source=/dev/null
		source "${configdirserver}/secrets-${selfname}.cfg"
	else
		# shellcheck source=/dev/null
		source "${configdirserver}/secrets-${selfname}.cfg"
	fi

	# Reloads start parameter to ensure all vars in startparameters are set.
	# Will reload the last defined startparameter.
	fn_reload_startparameters() {
		# reload Wurm config.
		if [ "${shortname}" == "wurm" ]; then
			# shellcheck source=/dev/null
			source "${servercfgfullpath}"
		fi
		# reload startparameters.
		if grep -qE "^[[:blank:]]*startparameters=" "${configdirserver}/secrets-${selfname}.cfg"; then
			eval startparameters="$(sed -nr 's/^ *startparameters=(.*)$/\1/p' "${configdirserver}/secrets-${selfname}.cfg")"
		elif grep -qE "^[[:blank:]]*startparameters=" "${configdirserver}/${selfname}.cfg"; then
			eval startparameters="$(sed -nr 's/^ *startparameters=(.*)$/\1/p' "${configdirserver}/${selfname}.cfg")"
		elif grep -qE "^[[:blank:]]*startparameters=" "${configdirserver}/secrets-common.cfg"; then
			eval startparameters="$(sed -nr 's/^ *startparameters=(.*)$/\1/p' "${configdirserver}/secrets-common.cfg")"
		elif grep -qE "^[[:blank:]]*startparameters=" "${configdirserver}/common.cfg"; then
			eval startparameters="$(sed -nr 's/^ *startparameters=(.*)$/\1/p' "${configdirserver}/common.cfg")"
		elif grep -qE "^[[:blank:]]*startparameters=" "${configdirserver}/_default.cfg"; then
			eval startparameters="$(sed -nr 's/^ *startparameters=(.*)$/\1/p' "${configdirserver}/_default.cfg")"
		fi

		# reload preexecutable.
		if grep -qE "^[[:blank:]]*preexecutable=" "${configdirserver}/secrets-${selfname}.cfg"; then
			eval preexecutable="$(sed -nr 's/^ *preexecutable=(.*)$/\1/p' "${configdirserver}/secrets-${selfname}.cfg")"
		elif grep -qE "^[[:blank:]]*preexecutable=" "${configdirserver}/${selfname}.cfg"; then
			eval preexecutable="$(sed -nr 's/^ *preexecutable=(.*)$/\1/p' "${configdirserver}/${selfname}.cfg")"
		elif grep -qE "^[[:blank:]]*preexecutable=" "${configdirserver}/secrets-common.cfg"; then
			eval preexecutable="$(sed -nr 's/^ *preexecutable=(.*)$/\1/p' "${configdirserver}/secrets-common.cfg")"
		elif grep -qE "^[[:blank:]]*preexecutable=" "${configdirserver}/common.cfg"; then
			eval preexecutable="$(sed -nr 's/^ *preexecutable=(.*)$/\1/p' "${configdirserver}/common.cfg")"
		elif grep -qE "^[[:blank:]]*preexecutable=" "${configdirserver}/_default.cfg"; then
			eval preexecutable="$(sed -nr 's/^ *preexecutable=(.*)$/\1/p' "${configdirserver}/_default.cfg")"
		fi

		# For legacy configs that still use parms= 15.03.21
		if grep -qE "^[[:blank:]]*parms=" "${configdirserver}/secrets-${selfname}.cfg"; then
			eval parms="$(sed -nr 's/^ *parms=(.*)$/\1/p' "${configdirserver}/secrets-${selfname}.cfg")"
		elif grep -qE "^[[:blank:]]*parms=" "${configdirserver}/${selfname}.cfg"; then
			eval parms="$(sed -nr 's/^ *parms=(.*)$/\1/p' "${configdirserver}/${selfname}.cfg")"
		elif grep -qE "^[[:blank:]]*parms=" "${configdirserver}/secrets-common.cfg"; then
			eval parms="$(sed -nr 's/^ *parms=(.*)$/\1/p' "${configdirserver}/secrets-common.cfg")"
		elif grep -qE "^[[:blank:]]*parms=" "${configdirserver}/common.cfg"; then
			eval parms="$(sed -nr 's/^ *parms=(.*)$/\1/p' "${configdirserver}/common.cfg")"
		elif grep -qE "^[[:blank:]]*parms=" "${configdirserver}/_default.cfg"; then
			eval parms="$(sed -nr 's/^ *parms=(.*)$/\1/p' "${configdirserver}/_default.cfg")"
		fi

		if [ -n "${parms}" ]; then
			startparameters="${parms}"
		fi
	}

	# Load the linuxgsm.sh in to tmpdir. If missing download it.
	if [ ! -f "${tmpdir}/linuxgsm.sh" ]; then
		fn_fetch_file_github "" "linuxgsm.sh" "${tmpdir}" "chmodx" "norun" "noforcedl" "nomd5"
	fi

	# Enables ANSI colours from core_messages.sh. Can be disabled with ansi=off.
	fn_ansi_loader

	getopt=$1
	core_getopt.sh
fi
