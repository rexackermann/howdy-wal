#!/bin/bash
###############################################################################
#             Howdy-WAL - Instant Lock Shortcut                          #
# --------------------------------------------------------------------------- #
# Use this script to rig a keyboard shortcut for instant locking.             #
###############################################################################

# Determine script location and load central configuration
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    # Fallback if installed in /opt/howdy-WAL
    source /opt/howdy-WAL/config.sh
fi

# We use sudo because lock_screen.sh requires it to switch VTs.
# The installer sets up a passwordless sudoers rule for this.
exec sudo "$LOCK_LAUNCHER_SCRIPT"
