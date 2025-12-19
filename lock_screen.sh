#!/bin/bash
###############################################################################
#             Howdy Autolock - System-Wide Lock Launcher                      #
# --------------------------------------------------------------------------- #
# This script handles the transition to a dedicated TTY and monitors the      #
# lock state to ensure the user cannot switch away easily.                    #
#                                                                             #
# WARNING: This script requires root privileges to manipulate TTY settings.   #
###############################################################################

# Determine script location and load central configuration
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    echo "CRITICAL ERROR: config.sh not found in $SCRIPT_DIR"
    exit 1
fi

# --- ROOT ELEVATION ---
# Check if running as root. If not, attempt to elevate using sudo.
if [ "$EUID" -ne 0 ]; then
    echo -e "\e[1;33m[ SYSTEM ]\e[0m Elevating privileges to access Virtual Terminals..."
    exec sudo "$0" "$@"
fi

# --- SESSION PRESERVATION ---
# Capture the current TTY so we can return the user to their desktop later.
ORIG_VT=$(fgconsole)
export TARGET_USER="${SUDO_USER:-$USER}"

echo -e "\e[1;32m[ LOCKING ]\e[0m Securing session on TTY $LOCK_VT..."

# --- TTY SWITCHING ---
# Clear any existing stale lock files
[ -f "$LOCK_FILE" ] && rm -f "$LOCK_FILE"

# Launch the UI script on a separate TTY.
# -c: VT number | -s: Switch to it | -f: Force
openvt -c "$LOCK_VT" -s -f -- "$LOCK_UI_SCRIPT"

# Wait for the UI script to initialize
sleep 1.5

# --- STICKY TTY ENFORCEMENT ---
# As long as the lock UI is running, we periodically check if the user 
# tried to Alt+Ctrl+Fx away. If they did, we drag them back.
SCRIPT_NAME=$(basename "$LOCK_UI_SCRIPT")

echo -e "\e[1;34m[ MONITORING ]\e[0m TTY Enforcement sequence active."

while pgrep -f "$SCRIPT_NAME" > /dev/null; do
    CURRENT_VT=$(fgconsole)
    # If VT is not the Lock VT AND not the Emergency VT, pull back.
    if [ "$CURRENT_VT" != "$LOCK_VT" ] && [ "$CURRENT_VT" != "$EMERGENCY_VT" ]; then
        # Intrusion detected! Focus restoration in progress.
        chvt "$LOCK_VT"
    fi
    sleep 0.5
done

# --- RESTORATION ---
echo -e "\e[1;32m[ UNLOCKED ]\e[0m Returning to session on TTY $ORIG_VT."
chvt "$ORIG_VT"
