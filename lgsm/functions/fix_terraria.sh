#!/bin/bash
# LinuxGSM fix_terraria.sh function
# Author: Daniel Gibbs
# Website: https://linuxgsm.com
# Description: Resolves an issue with Terraria.

local modulegroup="FIX"
local function_selfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

export TERM=xterm
