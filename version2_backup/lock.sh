#!/bin/bash
###############################################################################
#             Howdy-WAL - Native Session Lock Orchestrator                #
# --------------------------------------------------------------------------- #
# This script triggers GNOME's native screen lock mechanism. It is used as    #
# a reliable fallback for the biometric monitor.                              #
###############################################################################

# Determine script location and load central configuration
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    echo "CRITICAL ERROR: config.sh not found."
    exit 1
fi

# Log Event
log_event() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message"
    if [ -w "$LOG_FILE" ]; then
        echo "[$timestamp] [$level] $message" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" >> "$LOG_FILE"
    fi
}

# --- TRIGGER NATIVE LOCK ---
log_event "INFO" "Triggering Native GNOME Screen Lock..."

# GNOME Shell standard D-Bus Lock method
if gdbus call --session \
              --dest org.gnome.ScreenSaver \
              --object-path /org/gnome/ScreenSaver \
              --method org.gnome.ScreenSaver.Lock >/dev/null; then
    log_event "SUCCESS" "System Locked via Native ScreenSaver."
    exit 0
else
    log_event "ERROR" "Failed to trigger Native Lock. Check GNOME Session state."
    exit 1
fi
