#!/bin/bash
###############################################################################
#             Howdy Autolock - Caffeine Management                            #
# --------------------------------------------------------------------------- #
# This script toggles the "Caffeine" state, which prevents the monitor        #
# from triggering the lock even when the system is idle.                      #
###############################################################################

# Determine script location and load central configuration
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    CAFFEINE_FILE="/tmp/howdy_caffeine"
fi

# Toggling Logic
if [ -f "$CAFFEINE_FILE" ]; then
    rm -f "$CAFFEINE_FILE"
    echo -e "\e[1;33m[ CAFFEINE ]\e[0m \e[1;31mOFF\e[0m - Auto-lock system is now ACTIVE."
else
    touch "$CAFFEINE_FILE"
    echo -e "\e[1;33m[ CAFFEINE ]\e[0m \e[1;32mON\e[0m  - Auto-lock system is now PAUSED."
fi
