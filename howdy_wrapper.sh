#!/bin/bash
###############################################################################
#             Howdy-Wal - Biometric PAM Wrapper                          #
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

# Determine the target user for authentication.
# Normally inherited via SUDO_USER from the parent lock script.
TARGET_USER="${SUDO_USER:-$USER}"

# Execute biometric challenge
# service: faceauth | user: $TARGET_USER | action: authenticate
pamtester "$PAM_SERVICE" "$TARGET_USER" authenticate