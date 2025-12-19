#!/bin/bash
###############################################################################
#             Howdy-WAL - Non-TTY Overlay Orchestrator (V2)                #
# --------------------------------------------------------------------------- #
# This script manages the biometric lock flow.                                #
###############################################################################

# Determine script location and load central configuration
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
    cleanup_logs
else
    echo "CRITICAL ERROR: config.sh not found."
    exit 1
fi

# Atomic Lock
LOCK_FILE_INST="/tmp/howdy_wal_orchestrator.lock"
exec 200>$LOCK_FILE_INST
if ! flock -n 200; then
    echo "Check failed: Another lock orchestrator is already running."
    exit 0
fi

DBUS_DEST="org.gnome.Shell"
DBUS_PATH="/org/gnome/Shell/Extensions/HowdyWalOverlay"
DBUS_IFACE="org.gnome.Shell.Extensions.HowdyWalOverlay"

log_event() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message"
    if [ -w "$LOG_FILE" ]; then
        echo "[$timestamp] [$level] $message" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" >> "$LOG_FILE"
    fi
}

unlock_session() {
    log_event "INFO" "Releasing Overlay..."
    gdbus call --session --dest "$DBUS_DEST" --object-path "$DBUS_PATH" --method "$DBUS_IFACE.HideLock" > /dev/null
    log_event "SUCCESS" "Session Unlocked."
    exit 0
}

# Only trap external signals. Manual 'exit' will handle its own business.
trap unlock_session SIGINT SIGTERM

log_event "INFO" "Requesting GNOME Shell Overlay Lock..."
if ! gdbus call --session --dest "$DBUS_DEST" --object-path "$DBUS_PATH" --method "$DBUS_IFACE.ShowLock" >/dev/null; then
    log_event "ERROR" "D-Bus call failed. Extension might be disabled."
    exit 1
fi
log_event "SUCCESS" "Overlay Active. Session Secure."

AUTH_IN_PROGRESS=false

# Line-buffered signal monitoring
gdbus monitor --session --dest "$DBUS_DEST" --object-path "$DBUS_PATH" | while read -r line; do
    
    if echo "$line" | grep -q "InputDetected" && [ "$AUTH_IN_PROGRESS" = false ]; then
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

    if echo "$line" | grep -q "PasswordSubmitted"; then
        PASSWORD=$(echo "$line" | grep -oP "(?<=').*?(?=')")
        if python3 "$SCRIPT_DIR/pam_verify.py" "$TARGET_USER" "$PASSWORD" "$PAM_SERVICE"; then
            log_event "SUCCESS" "Password Verified."
            unlock_session
        else
            log_event "ERROR" "Incorrect Password. Re-locking..."
            sleep 1
            gdbus call --session --dest "$DBUS_DEST" --object-path "$DBUS_PATH" --method "$DBUS_IFACE.ShowPasswordPrompt" > /dev/null
        fi
    fi

done
