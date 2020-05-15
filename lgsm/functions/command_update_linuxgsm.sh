#!/bin/bash
# LinuxGSM command_update_linuxgsm.sh function
# Author: Daniel Gibbs
# Website: https://linuxgsm.com
# Description: Deletes the functions dir to allow re-downloading of functions from GitHub.

commandname="UPDATE-LGSM"
commandaction="Updating LinuxGSM"
functionselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

check.sh

fn_print_dots "Updating LinuxGSM"
fn_print_start_nl "Updating LinuxGSM"
fn_script_log_info "Updating LinuxGSM"

if [ -z "${legacymode}" ]; then
	# Check _default.cfg.
	remotereponame="GitHub"
	echo -en "checking ${remotereponame} config _default.cfg...\c"
	fn_script_log_info "Checking ${remotereponame} config _default.cfg"
	config_file_diff=$(diff "${configdirdefault}/config-lgsm/${gameservername}/_default.cfg" <(curl -s "https://raw.githubusercontent.com/${githubuser}/${githubrepo}/${githubbranch}/lgsm/config-default/config-lgsm/${gameservername}/_default.cfg"))
	if [ $? != "0" ]; then
		fn_print_error_eol_nl
		fn_script_log_error "Checking ${remotereponame} config _default.cfg: ERROR"
		remotereponame="Bitbucket"
		echo -en "checking ${remotereponame} config _default.cfg...\c"
		fn_script_log_info "Checking ${remotereponame} config _default.cfg"
		config_file_diff=$(diff "${configdirdefault}/config-lgsm/${gameservername}/_default.cfg" <(curl -s "https://bitbucket.org/${githubuser}/${githubrepo}/raw/${githubbranch}/lgsm/config-default/config-lgsm/${gameservername}/_default.cfg"))
		if [ $? != "0" ]; then
			fn_print_fail_eol_nl
			fn_script_log_fatal "Checking ${remotereponame} config _default.cfg: FAIL"
			core_exit.sh
		fi
	fi

	if [ "${config_file_diff}" != "" ]; then
		fn_print_update_eol_nl
		fn_script_log_info "Checking ${remotereponame} config _default.cfg: UPDATE"
		rm -f "${configdirdefault:?}/config-lgsm/${gameservername:?}/_default.cfg"
		fn_fetch_file_github "lgsm/config-default/config-lgsm/${gameservername}" "_default.cfg" "${configdirdefault}/config-lgsm/${gameservername}" "nochmodx" "norun" "noforce" "nomd5"
		alert="config"
		alert.sh
	else
		fn_print_ok_eol_nl
		fn_script_log_pass "Checking ${remotereponame} config _default.cfg: OK"
	fi

	# Check linuxsm.sh
	remotereponame="GitHub"
	echo -en "checking ${remotereponame} linuxgsm.sh...\c"
	fn_script_log_info "Checking ${remotereponame} linuxgsm.sh"
	tmp_script_diff=$(diff "${tmpdir}/linuxgsm.sh" <(curl -s "https://raw.githubusercontent.com/GameServerManagers/LinuxGSM/feature/update-lgsm/linuxgsm.sh"))
	if [ $? != "0" ]; then
		fn_print_error_eol_nl
		fn_script_log_error "Checking ${remotereponame} linuxgsm.sh: ERROR"
		remotereponame="Bitbucket"
		echo -en "checking ${remotereponame} linuxgsm.sh...\c"
		fn_script_log_info "Checking ${remotereponame} linuxgsm.sh"
		tmp_script_diff=$(diff "${tmpdir}/linuxgsm.sh" <(curl -s "https://bitbucket.org/${githubuser}/${githubrepo}/raw/${githubbranch}/linuxgsm.sh"))
		if [ $? != "0" ]; then
			fn_print_fail_eol_nl
			fn_script_log_fatal "Checking ${remotereponame} linuxgsm.sh: FAIL"
			core_exit.sh
		fi
	fi

	if [ "${tmp_script_diff}" != "" ]; then
		fn_print_update_eol_nl
		fn_script_log_info "Checking linuxgsm.sh: UPDATE"
		rm -f "${tmpdir:?}/linuxgsm.sh"
		fn_fetch_file_github "" "linuxgsm.sh" "${tmpdir}" "nochmodx" "norun" "noforcedl" "nomd5"
	else
		fn_print_ok_eol_nl
		fn_script_log_pass "checking linuxgsm.sh: OK"
	fi

	# Check gameserver.sh
	# Compare gameserver.sh against linuxgsm.sh in the tmp dir.
	# Ignoring server specific vars.
	echo -en "checking ${selfname}...\c"
	fn_script_log_info "Checking ${selfname}"
	script_diff=$(diff <(sed '\/shortname/d;\/gameservername/d;\/gamename/d;\/githubuser/d;\/githubrepo/d;\/githubbranch/d' "${tmpdir}/linuxgsm.sh") <(sed '\/shortname/d;\/gameservername/d;\/gamename/d;\/githubuser/d;\/githubrepo/d;\/githubbranch/d' "${rootdir}/${selfname}"))
	if [ "${script_diff}" != "" ]; then
		fn_print_update_eol_nl
		fn_script_log_info "Checking ${selfname}: UPDATE"
		echo -en "backup ${selfname}...\c"
		fn_script_log_info "Backup ${selfname}"
		if [ ! -d "${backupdir}/script" ]; then
			mkdir -p "${backupdir}/script"
		fi
		cp "${rootdir}/${selfname}" "${backupdir}/script/${selfname}-$(date +"%m_%d_%Y_%M").bak"
		if [ $? -ne 0 ]; then
			fn_print_fail_eol_nl
			fn_script_log_fatal "Backup ${selfname}: FAIL"
			core_exit.sh
		else
			fn_print_ok_eol_nl
			fn_script_log_pass "Backup ${selfname}: OK"
			echo -e "backup location ${backupdir}/script/${selfname}-$(date +"%m_%d_%Y_%M").bak"
			fn_script_log_pass "Backup location ${backupdir}/script/${selfname}-$(date +"%m_%d_%Y_%M").bak"
		fi

		echo -en "copying ${selfname}...\c"
		fn_script_log_info "copying ${selfname}"
		cp "${tmpdir}/linuxgsm.sh" "${rootdir}/${selfname}"
		sed -i "s/shortname=\"core\"/shortname=\"${shortname}\"/g" "${rootdir}/${selfname}"
		sed -i "s/gameservername=\"core\"/gameservername=\"${gameservername}\"/g" "${rootdir}/${selfname}"
		sed -i "s/gamename=\"core\"/gamename=\"${gamename}\"/g" "${rootdir}/${selfname}"
		if [ $? != "0" ]; then
			fn_print_fail_eol_nl
			fn_script_log_fatal "copying ${selfname}: FAIL"
			core_exit.sh
		else
			fn_print_ok_eol_nl
			fn_script_log_pass "copying ${selfname}: OK"
		fi
	else
		fn_print_ok_eol_nl
		fn_script_log_info "Checking ${selfname}: OK"
	fi
fi

# Check and update modules.
if [ -n "${functionsdir}" ]; then
	if [ -d "${functionsdir}" ]; then
		cd "${functionsdir}" || exit
		for functionfile in *
		do
			# check if file exists and remove if missing.
			get_function_file=$(curl --fail -s "https://raw.githubusercontent.com/${githubuser}/${githubrepo}/${githubbranch}/${github_file_url_dir}/${functionfile}")
			if [ $? != "0" ]; then
				get_function_file=$(curl --fail -s "https://bitbucket.org/${githubuser}/${githubrepo}/raw/${githubbranch}/${github_file_url_dir}/${functionfile}")
			fi
			if [ $? -ne 0 ]; then
				fn_print_fail_eol_nl
				echo -en "removing unknown function ${functionfile}...\c"
				fn_script_log_fatal "Removing unknown function ${functionfile}"
				if ! rm -f "${functionfile:?}"; then
					fn_print_fail_eol_nl
					core_exit.sh
				else
					fn_print_ok_eol_nl
				fi
			fi
			# compare file
			remotereponame="GitHub"
			echo -en "checking ${remotereponame} module ${functionfile}...\c"
			fn_script_log_info "Checking ${remotereponame} module ${functionfile}"
			function_file_diff=$(diff "${functionsdir}/${functionfile}" <(curl -s "https://raw.githubusercontent.com/${githubuser}/${githubrepo}/${githubbranch}/${github_file_url_dir}/${functionfile}"))
			if [ $? != "0" ]; then
				fn_print_error_eol_nl
				fn_script_log_error "Checking ${remotereponame} module ${functionfile}: ERROR"
				remotereponame="Bitbucket"
				echo -en "checking ${remotereponame} module ${functionfile}...\c"
				fn_script_log_info "Checking ${remotereponame} module ${functionfile}"
				function_file_diff=$(diff "${functionsdir}/${functionfile}" <(curl -s "https://bitbucket.org/${githubuser}/${githubrepo}/raw/${githubbranch}/${github_file_url_dir}/${functionfile}"))
			fi

			# results
			if [ "${function_file_diff}" != "" ]; then
				fn_print_update_eol_nl
				fn_script_log_info "Checking module ${functionfile}: UPDATE"
				rm -rf "${functionsdir:?}/${functionfile}"
				fn_update_function
			else
				fn_print_ok_eol_nl
			fi
		done
	fi
fi

fn_print_ok "Updating functions"
fn_script_log_pass "Updating functions"

core_exit.sh
