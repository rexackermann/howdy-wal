#!/bin/bash
###############################################################################
#             Howdy-WAL - System-Wide Lock Launcher                      #
# --------------------------------------------------------------------------- #
# This script handles the transition to a dedicated TTY and monitors the      #
# lock state to ensure the user cannot switch away easily.                    #
#                                                                             #
# HARDENED: Only returns to the desktop if successfully authenticated.        #
# If the lock UI crashes, it is immediately respawned.                        #
###############################################################################

# Determine script location and load central configuration
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    echo "CRITICAL ERROR: config.sh not found in $SCRIPT_DIR"
    exit 1
fi

# --- LOGGING HELPER ---
log_event() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message"
    if [ -w "$LOG_FILE" ]; then
        echo "[$timestamp] [$level] $message" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" >> "$LOG_FILE"
    fi
}

# --- ROOT ELEVATION ---
if [ "$EUID" -ne 0 ]; then
    echo -e "\e[1;33m[ SYSTEM ]\e[0m Elevating privileges..."
    exec sudo "$0" "$@"
fi

# --- SESSION PRESERVATION ---
ORIG_VT=$(fgconsole)
export TARGET_USER="${SUDO_USER:-$USER}"

log_event "INFO" "Securing session for $TARGET_USER on TTY $LOCK_VT..."

# --- ENFORCEMENT DAEMON ---
# We launch the "Sticky TTY" check in the background.
# It stays active as long as this parent script is running.
enforce_sticky_tty() {
    while true; do
        CURRENT_VT=$(fgconsole)
        # If VT is not the Lock VT AND not the Emergency VT, pull back.
        if [ "$CURRENT_VT" != "$LOCK_VT" ] && [ "$CURRENT_VT" != "$EMERGENCY_VT" ]; then
            chvt "$LOCK_VT"
        fi
        sleep 0.5
    done
}
enforce_sticky_tty &
STIKCY_PID=$!

# Ensure the background daemon is killed when this script exits
trap "kill $STIKCY_PID 2>/dev/null; exit" EXIT

# --- FAIL-CLOSED LAUNCH LOOP ---
# We use openvt -w (wait) to block until the UI script exits.
# If it exits with 0, it means authentication was successful.
# If it exits with anything else, it probably crashed, so we restart it.
while true; do
    echo -e "\e[1;34m[ LAUNCH ]\e[0m Starting Lock UI on TTY $LOCK_VT..."
    
    # openvt -w waits for the command to finish.
    # We use env to pass TERM explicitly to the project UI script.
    openvt -c "$LOCK_VT" -s -f -w -- env TERM=linux "$LOCK_UI_SCRIPT"
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "\e[1;32m[ SUCCESS ]\e[0m Authentication verified."
        break
    else
        echo -e "\e[1;31m[ CRASH ]\e[0m Lock UI terminated unexpectedly (Code: $EXIT_CODE). Respawning..."
        sleep 1
    fi
done

# --- RESTORATION ---
# CRITICAL: Kill the enforcement daemon BEFORE switching back, 
# otherwise it might pull us back to the lock VT during the switch.
[ -n "$STIKCY_PID" ] && kill "$STIKCY_PID" 2>/dev/null
wait "$STIKCY_PID" 2>/dev/null

log_event "SUCCESS" "Authentication verified. Returning to VT $ORIG_VT."
chvt "$ORIG_VT"

# Global cooldown notification for the monitor
touch "$LAST_UNLOCK_FILE" 2>/dev/null
chmod 666 "$LAST_UNLOCK_FILE" 2>/dev/null

exit 0
