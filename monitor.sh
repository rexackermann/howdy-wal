#!/bin/bash
###############################################################################
#             Howdy-WAL - System Idle Monitor Daemon (V2)                #
# --------------------------------------------------------------------------- #
# This version is "Shield-Aware" and avoids overlapping with GNOME's native   #
# lock screen.                                                                #
###############################################################################

# Determine script location and load central configuration
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    echo "CRITICAL ERROR: config.sh not found in $SCRIPT_DIR"
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
    # Check if GNOME's native ScreenShield is currently active
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
log_event "INFO" "Howdy-WAL Shield-Aware Monitor started."

while true; do
    # 1. Caffeine Check
    if [ -f "$CAFFEINE_FILE" ]; then
        sleep 10
        continue
    fi

    # 2. Native ScreenShield Check
    # If the system is already locked by GDM/GNOME, don't overlap.
    if is_native_lock_active; then
        sleep 10
        continue
    fi

    # 3. Smart Media Logic
    if [ "$SMART_MEDIA" = true ] && [ -f "$MEDIA_CHECK_SCRIPT" ]; then
        if "$MEDIA_CHECK_SCRIPT"; then
            sleep 5
            continue
        fi
    fi

    # 4. Idle Check
    IDLE_MS=$(get_idle_time)
    if [ -z "$IDLE_MS" ]; then
        sleep 5
        continue
    fi

    # 5. Lock Decision
    if [ "$IDLE_MS" -gt "$IDLE_THRESHOLD_MS" ]; then
        # Precise process check
        if ! pgrep -x "lock.sh" >/dev/null; then
            log_event "TRIGGER" "Idle limit reached ($IDLE_MS ms)."
            
            # Pre-lock check: Is the user still there?
            if ! "$HOWDY_WRAPPER_SCRIPT" >/dev/null 2>&1; then
                log_event "LOCK" "User absent. Activating Overlay."
                "$LOCK_SCRIPT"
                log_event "RESUME" "Unlocked. Grace period ($UNLOCK_GRACE_PERIOD s)."
                sleep "$UNLOCK_GRACE_PERIOD"
            else
                log_event "INFO" "User present at desk. Extending idle..."
                sleep 30
            fi
        fi
    fi

    sleep 2
done
