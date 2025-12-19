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

# --- ROOT ELEVATION ---
if [ "$EUID" -ne 0 ]; then
    echo -e "\e[1;33m[ SYSTEM ]\e[0m Elevating privileges..."
    exec sudo "$0" "$@"
fi

# --- SESSION PRESERVATION ---
ORIG_VT=$(fgconsole)
export TARGET_USER="${SUDO_USER:-$USER}"

echo -e "\e[1;32m[ LOCKING ]\e[0m Securing session on TTY $LOCK_VT..."

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
    # We wrap in bash -c to ensure TERM is explicitly set for ncurses/tmatrix.
    openvt -c "$LOCK_VT" -s -f -w -- /bin/bash -c "export TERM=linux; $LOCK_UI_SCRIPT"
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
echo -e "\e[1;32m[ UNLOCKED ]\e[0m Authenticated. Returning to VT $ORIG_VT."
chvt "$ORIG_VT"
