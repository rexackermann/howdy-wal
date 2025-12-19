#!/bin/bash
###############################################################################
# lock_now.sh - Instant V2 Lock Shortcut                                     #
# --------------------------------------------------------------------------- #
# Triggers the session-native lock immediately.                               #
###############################################################################

# Determine script location and load central configuration
INSTALL_DIR="/opt/howdy-WAL"
if [ -f "$INSTALL_DIR/config.sh" ]; then
    source "$INSTALL_DIR/config.sh"
fi

# In V2, locking is a D-Bus call, no sudo required.
exec "$INSTALL_DIR/lock.sh"
