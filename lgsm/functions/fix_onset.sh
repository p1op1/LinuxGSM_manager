#!/bin/bash
# LinuxGSM fix_onset.sh module
# Author: Daniel Gibbs
# Website: https://linuxgsm.com
# Contributors: http://linuxgsm.com/contrib
# Description: Resolves various issues with Onset.

functionselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${serverfiles}"

# Fixes: Failed loading "mariadb": libmariadbclient.so.18: cannot open shared object file: No such file or directory
# Issue only occures on CentOS as libmariadbclient.so.18 is called libmariadb.so.3 on CentOS.
if [ -f "/etc/redhat-release" ]&&[ ! -f "${serverfiles}/libmariadbclient.so.18" ]&&[ -f "/usr/lib64/libmariadb.so.3" ]; then
	fixname="libmariadbclient.so.18"
	fn_fix_msg_start
	ln -s "/usr/lib64/libmariadb.so.3" "${serverfiles}/libmariadbclient.so.18"
	fn_fix_msg_end
fi
