#!/bin/bash
###############################################################################
#             Howdy-WAL - Biometric PAM Wrapper                          #
# --------------------------------------------------------------------------- #
# This script invokes pamtester with the designated biometric service.        #
# It is used by the monitor and the UI for presence verification.             #
###############################################################################

# Determine script location and load central configuration
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    # Fallback if config is missing (unlikely after install)
    PAM_SERVICE="faceauth"
fi

# Helper: Check if Native GNOME Lock is active
is_native_lock_active() {
    # Only relevant if NATIVE_LOCK is enabled in config
    if [[ "$NATIVE_LOCK" != "true" ]]; then
        return 1
    fi
    # If we are on a TTY, this D-Bus call might fail or return false.
    # That is desired, as we want Howdy to work on the TTY lock.
    local status
    status=$(gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.GetActive 2>/dev/null)
    if [[ "$status" == "(true,)" ]]; then
        return 0
    fi
    return 1
}

# ABORT if the system is already natively locked.
# This prevents the monitor from "blasting" IR while GDM is also trying to use the camera.
if is_native_lock_active; then
    exit 1
fi

# Determine the target user for authentication.
# Normally inherited via SUDO_USER from the parent lock script.
TARGET_USER="${SUDO_USER:-$USER}"

# Execute biometric challenge
# service: faceauth | user: $TARGET_USER | action: authenticate
pamtester "$PAM_SERVICE" "$TARGET_USER" authenticate