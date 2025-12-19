#!/bin/bash
###############################################################################
#             Howdy-WAL - System Idle Monitor Daemon (V2)                #
# --------------------------------------------------------------------------- #
# This background service watches for system idleness and triggers the        #
# biometric verification and overlay lock for the current session.            #
###############################################################################

# Determine script location and load central configuration
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    echo "CRITICAL ERROR: config.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Define paths if not in config
MEDIA_CHECK_SCRIPT="${MEDIA_CHECK_SCRIPT:-$INSTALL_DIR/media_check.sh}"
CAFFEINE_SCRIPT="${CAFFEINE_SCRIPT:-$INSTALL_DIR/caffeine.sh}"
CAFFEINE_FILE="${CAFFEINE_FILE:-/tmp/howdy_caffeine}"
LOCK_SCRIPT="${LOCK_SCRIPT:-$INSTALL_DIR/lock.sh}"

# --- IDLE DETECTION LOGIC ---
get_idle_time() {
    gdbus call --session \
               --dest org.gnome.Mutter.IdleMonitor \
               --object-path /org/gnome/Mutter/IdleMonitor/Core \
               --method org.gnome.Mutter.IdleMonitor.GetIdletime 2>/dev/null \
               | awk -F' ' '{print $2}' | tr -cd '0-9'
}

# --- LOGGING HELPER ---
log_event() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null
    echo -e "[$timestamp] [$level] $message"
}

cleanup_logs
log_event "INFO" "Howdy-WAL V2 Monitor starting up..."

while true; do
    # 1. Caffeine Check
    if [ -f "$CAFFEINE_FILE" ]; then
        sleep 10
        continue
    fi

    # 2. Smart Media Logic
    if [ -f "$MEDIA_CHECK_SCRIPT" ]; then
        if "$MEDIA_CHECK_SCRIPT"; then
            sleep 5
            continue
        fi
    fi

    # 3. Get Idle Time
    IDLE_MS=$(get_idle_time)
    if [ -z "$IDLE_MS" ]; then
        sleep 5
        continue
    fi

    # 4. Trigger Lock
    if [ "$IDLE_MS" -gt "$IDLE_THRESHOLD_MS" ]; then
        # Check if lock is already running
        if ! pgrep -f "$(basename "$LOCK_SCRIPT")" >/dev/null; then
            log_event "TRIGGER" "Idle threshold reached ($IDLE_MS ms). Checking presence..."
            
            if ! "$HOWDY_WRAPPER_SCRIPT"; then
                log_event "LOCK" "User not detected. Locking session."
                "$LOCK_SCRIPT"
                log_event "RESUME" "Session resumed. Grace period ($UNLOCK_GRACE_PERIOD s)."
                sleep "$UNLOCK_GRACE_PERIOD"
            else
                log_event "INFO" "User detected. Skipping lock."
                sleep 5
            fi
        fi
    fi

    sleep 1
done
