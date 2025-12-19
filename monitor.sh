#!/bin/bash
###############################################################################
#             Howdy-WAL - Smart Monitor for Native Locking                #
# --------------------------------------------------------------------------- #
# This monitor watches for idleness and triggers the native GNOME lock        #
# only if "Smart" conditions (Media, Caffeine, Face) are NOT met.             #
###############################################################################

# Determine script location and load central configuration
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    echo "CRITICAL ERROR: config.sh not found."
    exit 1
fi

# Paths
LOCK_SCRIPT="$INSTALL_DIR/lock.sh"
MEDIA_CHECK_SCRIPT="$INSTALL_DIR/media_check.sh"

# --- HELPERS ---
get_idle_time() {
    gdbus call --session \
               --dest org.gnome.Mutter.IdleMonitor \
               --object-path /org/gnome/Mutter/IdleMonitor/Core \
               --method org.gnome.Mutter.IdleMonitor.GetIdletime 2>/dev/null \
               | awk -F' ' '{print $2}' | tr -cd '0-9'
}

is_native_lock_active() {
    local status
    status=$(gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.GetActive 2>/dev/null)
    if [[ "$status" == "(true,)" ]]; then
        return 0
    fi
    return 1
}

log_event() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null
    [ "$VERBOSE" = true ] && echo -e "[$timestamp] [$level] $message"
}

cleanup_logs
log_event "INFO" "Howdy-WAL Smart Monitor (Native) starting up..."

while true; do
    # 1. Caffeine Check
    if [ -f "$CAFFEINE_FILE" ]; then
        sleep 10
        continue
    fi

    # 2. Native ScreenShield Check
    # If the system is already locked by the OS, don't do anything.
    if is_native_lock_active; then
        sleep 15
        continue
    fi

    # 3. Smart Media Logic (Using V1 Focus Exporter)
    if [ "$SMART_MEDIA" = true ] && [ -f "$MEDIA_CHECK_SCRIPT" ]; then
        if "$MEDIA_CHECK_SCRIPT"; then
            sleep 5
            continue
        fi
    fi

    # 4. Idle Detection
    IDLE_MS=$(get_idle_time)
    if [ -z "$IDLE_MS" ]; then
        sleep 5
        continue
    fi

    # 5. Lock Decision Engine
    if [ "$IDLE_MS" -gt "$IDLE_THRESHOLD_MS" ]; then
        log_event "TRIGGER" "Idle threshold reached ($IDLE_MS ms). Checking presence..."
        
        # PROACTIVE BYPASS: Check if user is still sitting there
        if ! "$HOWDY_WRAPPER_SCRIPT" >/dev/null 2>&1; then
            log_event "LOCK" "Authentication Failed (User not found). Triggering Native Lock."
            "$LOCK_SCRIPT"
            
            # Wait for user to unlock and then hold off briefly
            log_event "RESUME" "Session resumed. Entering grace period ($UNLOCK_GRACE_PERIOD s)."
            sleep "$UNLOCK_GRACE_PERIOD"
        else
            log_event "INFO" "User detected. Skipping lock and extending idle period."
            # Sleep a bit to avoid constant scanning if user is active but not moving mouse
            sleep 30
        fi
    fi

    sleep 2
done
