#!/bin/bash
###############################################################################
#             Howdy-WAL - Non-TTY Overlay Orchestrator                        #
# --------------------------------------------------------------------------- #
# This script manages the GNOME Shell Overlay and handles the authentication  #
# flow within the current session.                                            #
###############################################################################

# Determine script location and load central configuration
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
    cleanup_logs
else
    echo "CRITICAL ERROR: config.sh not found in $SCRIPT_DIR"
    exit 1
fi

# --- ATOMIC LOCK CHECK ---
# Prevent multiple instances of the orchestrator from running simultaneously.
LOCK_FILE_INST="/tmp/howdy_wal_orchestrator.lock"
exec 200>$LOCK_FILE_INST
if ! flock -n 200; then
    echo "Check failed: Another lock orchestrator is already running."
    exit 0
fi

# D-Bus Configuration
DBUS_DEST="org.gnome.Shell"
DBUS_PATH="/org/gnome/Shell/Extensions/HowdyWalOverlay"
DBUS_IFACE="org.gnome.Shell.Extensions.HowdyWalOverlay"

# State Flags
AUTH_IN_PROGRESS=false

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

# --- UNLOCK FUNCTION ---
unlock_session() {
    log_event "INFO" "Releasing Overlay..."
    # Notify extension to clear screen
    gdbus call --session --dest "$DBUS_DEST" --object-path "$DBUS_PATH" --method "$DBUS_IFACE.HideLock" > /dev/null
    log_event "SUCCESS" "Session Unlocked."
    
    # Disable trap before manual exit to prevent recursion
    trap - EXIT
    exit 0
}

# --- EMERGENCY CLEANUP ---
emergency_exit() {
    log_event "WARN" "Script interrupted or emergency exit triggered."
    gdbus call --session --dest "$DBUS_DEST" --object-path "$DBUS_PATH" --method "$DBUS_IFACE.HideLock" > /dev/null
    exit 1
}

# Trap signals for cleanup
trap emergency_exit SIGINT SIGTERM EXIT

# --- LOCK TRIGGER ---
log_event "INFO" "Requesting GNOME Shell Overlay Lock..."
SUCCESS=$(gdbus call --session --dest "$DBUS_DEST" --object-path "$DBUS_PATH" --method "$DBUS_IFACE.ShowLock")

if [[ "$SUCCESS" != "(true,)" ]]; then
    log_event "ERROR" "Failed to activate Shield Overlay. Is the extension enabled?"
    exit 1
fi

log_event "SUCCESS" "Overlay Active. Session Secure."

# --- MAIN MONITOR LOOP ---
# Use line-buffered monitoring to prevent getting stuck in buffers
gdbus monitor --session --dest "$DBUS_DEST" --object-path "$DBUS_PATH" | while read -r line; do
    
    # 1. Handle Interaction (Wake)
    if echo "$line" | grep -q "InputDetected"; then
        if [ "$AUTH_IN_PROGRESS" = true ]; then
            continue # Already scanning or showing prompt
        fi
        
        AUTH_IN_PROGRESS=true
        log_event "INFO" "Wake gesture detected. Triggering Face Check..."
        
        if "$HOWDY_WRAPPER_SCRIPT"; then
            log_event "SUCCESS" "Face Verified."
            unlock_session
        else
            log_event "WARN" "Face scan failed. Requesting Password Prompt..."
            gdbus call --session --dest "$DBUS_DEST" --object-path "$DBUS_PATH" --method "$DBUS_IFACE.ShowPasswordPrompt" > /dev/null
        fi
    fi

    # 2. Handle Password Submission
    if echo "$line" | grep -q "PasswordSubmitted"; then
        # Extract password between single quotes 'pass'
        PASSWORD=$(echo "$line" | grep -oP "(?<=').*?(?=')")
        
        log_event "DEBUG" "Password received. Verifying..."
        
        # Verify via Python PAM helper
        if python3 "$SCRIPT_DIR/pam_verify.py" "$TARGET_USER" "$PASSWORD" "$PAM_SERVICE"; then
            log_event "SUCCESS" "Password Verified."
            unlock_session
        else
            log_event "ERROR" "Incorrect Password. Re-locking..."
            sleep 1
            # Prompt again
            gdbus call --session --dest "$DBUS_DEST" --object-path "$DBUS_PATH" --method "$DBUS_IFACE.ShowPasswordPrompt" > /dev/null
        fi
    fi
done
