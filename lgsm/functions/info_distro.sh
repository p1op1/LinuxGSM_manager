#!/usr/bin/env bash
# LinuxGSM info_distro.sh function
# Author: Daniel Gibbs
# Website: https://linuxgsm.com
# Description: Variables providing useful info on the Operating System such as disk and performace info.
# Used for command_details.sh, command_debug.sh and alert.sh.

local function_selfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

### Distro information

## Distro
# Returns architecture, kernel and distro/os.
arch=$(uname -m)
kernel=$(uname -r)
os=$(uname -s)

# Distro Name - Ubuntu 16.04 LTS
# Distro Version - 16.04
# Distro ID - ubuntu
# Distro Codename - xenial

# Gathers distro info from various sources filling in missing gaps.
if [ "${os}" = "FreeBSD" ]; then
	distroname="FreeBSD"
	distroversion="$(uname -r)"
	distroid="freebsd"
else
	distro_info_array=( os-release lsb_release hostnamectl debian_version redhat-release )
	for distro_info in "${distro_info_array[@]}"
	do
		if [ -f "/etc/os-release" ]&&[ "${distro_info}" == "os-release" ]; then
			distroname=$(grep PRETTY_NAME /etc/os-release | sed 's/PRETTY_NAME=//g' | tr -d '="' | sed 's/\"//g')
			distroversion=$(grep VERSION_ID /etc/os-release | sed 's/VERSION_ID=//g' | sed 's/\"//g')
			distroid=$(grep ID /etc/os-release | grep -v _ID | grep -v ID_ | sed 's/ID=//g' | sed 's/\"//g')
			distrocodename=$(grep VERSION_CODENAME /etc/os-release | sed 's/VERSION_CODENAME=//g' | sed 's/\"//g')
		elif [ -n "$(command -v lsb_release 2>/dev/null)" ]&&[ "${distro_info}" == "lsb_release" ]; then
			if [ -z "${distroname}" ];then
				distroname="$(lsb_release -sd)"
			elif [ -z "${distroversion}" ];then
				distroversion="$(lsb_release -sr)"
			elif [ -z "${distroid}" ];then
				distroid=$(lsb_release -si)
			elif [ -z "${distrocodename}" ];then
				distrocodename=$(lsb_release -sc)
			fi
		elif [ -n "$(command -v hostnamectl 2>/dev/null)" ]&&[ "${distro_info}" == "hostnamectl" ]; then
			if [ -z "${distroname}" ];then
				distroname="$(hostnamectl | grep "Operating System" | sed 's/Operating System: //g')"
			fi
		elif [ -f "/etc/debian_version" ]&&[ "${distro_info}" == "debian_version" ]; then
			if [ -z "${distroname}" ];then
				distroname="Debian $(cat /etc/debian_version)"
			elif [ -z "${distroversion}" ];then
				distroversion="$(cat /etc/debian_version)"
			elif [ -z "${distroid}" ];then
				distroid="debian"
			fi
		elif [ -f "/etc/redhat-release" ]&&[ "${distro_info}" == "redhat-release" ]; then
			if [ -z "${distroname}" ];then
				distroname=$(cat /etc/redhat-release)
			elif [ -z "${distroversion}" ];then
				distroversion=$(rpm -qa \*-release | grep -Ei "oracle|redhat|centos|fedora" | cut -d"-" -f3)
			elif [ -z "${distroid}" ];then
				distroid="$(awk '{print $1}' /etc/redhat-release)"
			fi
		fi
	done
fi

## Glibc version
# e.g: 1.17
if [ "${os}" = "FreeBSD" ]; then
	glibcversion="0.0"
else
	glibcversion="$(ldd --version | sed -n '1s/.* //p')"
fi

## tmux version
# e.g: tmux 1.6
if [ -z "$(command -V tmux 2>/dev/null)" ]; then
	tmuxv="${red}NOT INSTALLED!${default}"
else
	if [ "$(tmux -V|sed "s/tmux //" | sed -n '1 p' | tr -cd '[:digit:]')" -lt "16" ] 2>/dev/null; then
		tmuxv="$(tmux -V) (>= 1.6 required for console log)"
	else
		tmuxv=$(tmux -V)
	fi
fi

## Uptime
if [ "${os}" = "FreeBSD" ]; then
	boottime=$(sysctl -n kern.boottime | sed -E 's/^.* sec = ([0-9]+).*$/\1/')
	uptime=$(($(date +%s)-boottime))
	minutes=$(( uptime/60%60 ))
	hours=$(( uptime/60/60%24 ))
	days=$(( uptime/60/60/24 ))
else
	uptime=$(</proc/uptime)
	uptime=${uptime/[. ]*/}
	minutes=$(( uptime/60%60 ))
	hours=$(( uptime/60/60%24 ))
	days=$(( uptime/60/60/24 ))
fi

### Performance information

## Average server load
if [ "${os}" = "FreeBSD" ]; then
	load=$(uptime|awk -F 'load averages: ' '{ print $2 }')
else
	load=$(uptime|awk -F 'load average: ' '{ print $2 }')
fi

## CPU information
if [ "${os}" = "FreeBSD" ]; then
	cpumodel=$(sysctl -n hw.model)
	cpucores=$(sysctl -n hw.ncpu)
	cpufreuency=$(sysctl -i -n dev.cpu.0.freq)
	if [ -z "${cpufreuency}" ]; then # Workaround for FreeBSD bug #162043
		cpufreuency="Unknown"
	fi
else
	cpumodel=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
	cpucores=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
	cpufreuency=$(awk -F: ' /cpu MHz/ {freq=$2} END {print freq " MHz"}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
fi

## Memory information
# Available RAM and swap.

if [ "${os}" = "FreeBSD" ]; then
	physmemtotalkb=$(($(sysctl -n hw.physmem)/1024))
	physmemfreekb=$(($(vmstat -H | awk 'END {print $5}')/1024))
	physmemtotalmb=$((physmemtotalkb/1024))
	physmemtotal=$((physmemtotalkb*1048576))
	physmemfree=$((physmemfreekb*1048576))
	physmemused=$((physmemtotal-physmemfree))
	physmemavailable=$((physmemfreekb*1048576))
	physmemcached=0

	swaptotal=$(swapinfo | awk 'END {print $2}')
	swapfree=$(swapinfo | awk 'END {print $4}')
	swapused=$(swapinfo | awk 'END {print $3}')
elif [ -n "$(command -v numfmt 2>/dev/null)" ]; then
# Newer distros can use numfmt to give more accurate results.
	# Issue #2005 - Kernel 3.14+ contains MemAvailable which should be used. All others will be calculated.

	# get the raw KB values of these fields.
	physmemtotalkb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
	physmemfreekb=$(grep ^MemFree /proc/meminfo | awk '{print $2}')
	physmembufferskb=$(grep ^Buffers /proc/meminfo | awk '{print $2}')
	physmemcachedkb=$(grep ^Cached /proc/meminfo | awk '{print $2}')
	physmemreclaimablekb=$(grep ^SReclaimable /proc/meminfo | awk '{print $2}')

	# check if MemAvailable Exists.
	if grep -q ^MemAvailable /proc/meminfo; then
	    physmemactualfreekb=$(grep ^MemAvailable /proc/meminfo | awk '{print $2}')
	else
	    physmemactualfreekb=$((${physmemfreekb}+${physmembufferskb}+${physmemcachedkb}))
	fi

	# Available RAM and swap.
	physmemtotalmb=$((${physmemtotalkb}/1024))
	physmemtotal=$(numfmt --to=iec --from=iec --suffix=B "${physmemtotalkb}K")
	physmemfree=$(numfmt --to=iec --from=iec --suffix=B "${physmemactualfreekb}K")
	physmemused=$(numfmt --to=iec --from=iec --suffix=B "$((${physmemtotalkb}-${physmemfreekb}-${physmembufferskb}-${physmemcachedkb}-${physmemreclaimablekb}))K")
	physmemavailable=$(numfmt --to=iec --from=iec --suffix=B "${physmemactualfreekb}K")
	physmemcached=$(numfmt --to=iec --from=iec --suffix=B "$((${physmemcachedkb}+${physmemreclaimablekb}))K")

	swaptotal=$(numfmt --to=iec --from=iec --suffix=B "$(grep ^SwapTotal /proc/meminfo | awk '{print $2}')K")
	swapfree=$(numfmt --to=iec --from=iec --suffix=B "$(grep ^SwapFree /proc/meminfo | awk '{print $2}')K")
	swapused=$(numfmt --to=iec --from=iec --suffix=B "$(($(grep ^SwapTotal /proc/meminfo | awk '{print $2}')-$(grep ^SwapFree /proc/meminfo | awk '{print $2}')))K")
else
# Older distros will need to use free.
	# Older versions of free do not support -h option.
	if [ "$(free -h > /dev/null 2>&1; echo $?)" -ne "0" ]; then
		humanreadable="-m"
	else
		humanreadable="-h"
	fi
	physmemtotalmb=$(free -m | awk '/Mem:/ {print $2}')
	physmemtotal=$(free ${humanreadable} | awk '/Mem:/ {print $2}')
	physmemfree=$(free ${humanreadable} | awk '/Mem:/ {print $4}')
	physmemused=$(free ${humanreadable} | awk '/Mem:/ {print $3}')

	oldfree=$(free ${humanreadable} | awk '/cache:/')
	if [ -n "${oldfree}" ]; then
		physmemavailable="n/a"
		physmemcached="n/a"
	else
		physmemavailable=$(free ${humanreadable} | awk '/Mem:/ {print $7}')
		physmemcached=$(free ${humanreadable} | awk '/Mem:/ {print $6}')
	fi

	swaptotal=$(free ${humanreadable} | awk '/Swap:/ {print $2}')
	swapused=$(free ${humanreadable} | awk '/Swap:/ {print $3}')
	swapfree=$(free ${humanreadable} | awk '/Swap:/ {print $4}')
fi

### Disk information

## Available disk space on the partition.
if [ "${os}" = "FreeBSD" ]; then
	dfflag=-h
else
	dfflag=-hP
fi
filesystem=$(df "${dfflag}" "${rootdir}" | grep -v "Filesystem" | awk '{print $1}')
totalspace=$(df "${dfflag}" "${rootdir}" | grep -v "Filesystem" | awk '{print $2}')
usedspace=$(df "${dfflag}" "${rootdir}" | grep -v "Filesystem" | awk '{print $3}')
availspace=$(df "${dfflag}" "${rootdir}" | grep -v "Filesystem" | awk '{print $4}')

## LinuxGSM used space total.
rootdirdu=$(du -sh "${rootdir}" 2> /dev/null | awk '{print $1}')
if [ -z "${rootdirdu}" ]; then
	rootdirdu="0M"
fi

## LinuxGSM used space in serverfiles dir.
serverfilesdu=$(du -sh "${serverfiles}" 2> /dev/null | awk '{print $1}')
if [ -z "${serverfilesdu}" ]; then
	serverfilesdu="0M"
fi

## LinuxGSM used space total minus backup dir.
rootdirduexbackup=$(du -sh --exclude="${backupdir}" "${serverfiles}" 2> /dev/null | awk '{print $1}')
if [ -z "${rootdirduexbackup}" ]; then
	rootdirduexbackup="0M"
fi

## Backup info
if [ -d "${backupdir}" ]; then
	# Used space in backups dir.
	backupdirdu=$(du -sh "${backupdir}" | awk '{print $1}')
	# If no backup dir, size is 0M.
	if [ -z "${backupdirdu}" ]; then
		backupdirdu="0M"
	fi

	# number of backups set to 0 by default.
	backupcount=0

	# If there are backups in backup dir.
	if [ "$(find "${backupdir}" -name "*.tar.gz" | wc -l)" -ne "0" ]; then
		# number of backups.
		backupcount=$(find "${backupdir}"/*.tar.gz | wc -l)
		# most recent backup.
		lastbackup=$(find "${backupdir}"/*.tar.gz | head -1)
		# date of most recent backup.
		lastbackupdate=$(date -r "${lastbackup}")
		# no of days since last backup.
		lastbackupdaysago=$(( ( $(date +'%s') - $(date -r "${lastbackup}" +'%s') )/60/60/24 ))
		# size of most recent backup.
		lastbackupsize=$(du -h "${lastbackup}" | awk '{print $1}')
	fi
fi

# External IP address
if [ -z "${extip}" ]; then
	extip=$(${curlpath} -4 -m 3 ifconfig.co 2>/dev/null)
	exitcode=$?
	# Should ifconfig.co return an error will use last known IP.
	if [ ${exitcode} -eq 0 ]; then
		echo "${extip}" > "${tmpdir}/extip.txt"
	else
		if [ -f "${tmpdir}/extip.txt" ]; then
			extip=$(cat ${tmpdir}/extip.txt)
		else
			echo "x.x.x.x"
		fi
	fi
fi

# Alert IP address
if [ "${displayip}" ]; then
	alertip="${displayip}"
elif [ "${extip}" ]; then
	alertip="${extip}"
else
	alertip="${ip}"
fi

# Steam Master Server - checks if detected by master server.
if [ "$(command -v jq 2>/dev/null)" ]; then
	if [ "${ip}" ]&&[ "${port}" ]; then
		if [ "${steammaster}" == "true" ]; then
			masterserver=$(${curlpath} -m 3 -s 'https://api.steampowered.com/ISteamApps/GetServersAtAddress/v0001?addr='${ip}':'${port}'&format=json' | jq '.response.servers[]|.addr' | wc -l)
			if [ "${masterserver}" == "0" ]; then
				masterserver=$(${curlpath} -m 3 -s 'https://api.steampowered.com/ISteamApps/GetServersAtAddress/v0001?addr='${extip}':'${port}'&format=json' | jq '.response.servers[]|.addr' | wc -l)
			fi
			if [ "${masterserver}" == "0" ]; then
				masterserver="false"
			else
				masterserver="true"
			fi
		fi
	fi
fi

# Sets the SteamCMD glibc requirement if the game server requirement is less or not required.
if [ -n "${appid}" ]; then
	if [ "${glibc}" = "null" ]||[ -z "${glibc}" ]||[ "$(printf '%s\n'${glibc}'\n' "2.14" | sort -V | head -n 1)" != "2.14" ]; then
		glibc="2.14"
	fi
fi
