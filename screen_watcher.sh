#!/bin/bash
###############################################################################
#             Howdy-WAL - System Idle Monitor Daemon                     #
# --------------------------------------------------------------------------- #
# This background service watches for system idleness and triggers the        #
# biometric verification or the lock screen as necessary.                     #
###############################################################################

# Determine script location and load central configuration
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    echo "CRITICAL ERROR: config.sh not found in $SCRIPT_DIR"
    exit 1
fi

# --- IDLE DETECTION LOGIC ---
# Intererrogates GNOME's Mutter IdleMonitor via D-Bus.
get_idle_time() {
    gdbus call --session \
               --dest org.gnome.Mutter.IdleMonitor \
               --object-path /org/gnome/Mutter/IdleMonitor/Core \
               --method org.gnome.Mutter.IdleMonitor.GetIdletime 2>/dev/null \
               | awk -F' ' '{print $2}' | tr -cd '0-9'
}

# --- MEDIA DETECTION LOGIC ---

# Check if audio is currently being played.
# Returns 0 if audio is detected, 1 otherwise.
is_audio_playing() {
    local status
    if [ "$ONLY_RUNNING_AUDIO" = true ]; then
        # Check specifically for sink inputs with state 'RUNNING'
        status=$(pactl list sink-inputs 2>/dev/null | grep -c "state: RUNNING")
    else
        # Check for any active sink inputs
        status=$(pactl list sink-inputs 2>/dev/null | grep -c "sink-input")
    fi
    
    [ "$status" -gt 0 ] && return 0 || return 1
}

# Check if GNOME session is inhibiting idle.
# Returns 0 if inhibited, 1 otherwise.
is_idle_inhibited() {
    local inhibited
    inhibited=$(gdbus call --session \
                           --dest org.gnome.SessionManager \
                           --object-path /org/gnome/SessionManager \
                           --method org.gnome.SessionManager.IsInhibited 8 2>/dev/null \
                           | grep -o "true" | wc -l)
    
    [ "$inhibited" -gt 0 ] && return 0 || return 1
}

echo -e "\e[1;36m[ DAEMON ]\e[0m Howdy-WAL Monitor starting up..."

# --- MAIN MONITORING LOOP ---
while true; do
    # 1. Caffeine Check
    if [ -f "$CAFFEINE_FILE" ]; then
        sleep 10
        continue
    fi

    # 2. Smart Media Logic
    if [ "$SMART_MEDIA" = true ]; then
        if is_audio_playing; then
            if is_idle_inhibited; then
                # Media is playing AND something is inhibiting idle (Foreground Video/Presentation)
                # We do NOT lock.
                sleep 5
                continue
            fi
            # Note: If audio is playing but NOT inhibited, it's "Background Audio" (Spotify, etc)
            # In this case, we CONTINUE to the idle check and may lock.
        fi
    fi

    # 3. Get current system idle time (milliseconds)
    IDLE_MS=$(get_idle_time)
    
    # Handle environment issues (e.g. D-Bus not ready)
    if [ -z "$IDLE_MS" ]; then
        # echo "Warning: Unable to retrieve idle time."
        sleep 5
        continue
    fi

    # 3. Decision Logic
    if [ "$IDLE_MS" -gt "$IDLE_THRESHOLD_MS" ]; then
        
        # Ensure we aren't already locked
        UI_SCRIPT_NAME=$(basename "$LOCK_UI_SCRIPT")
        if ! pgrep -f "$UI_SCRIPT_NAME" >/dev/null; then
            
            echo -e "\e[1;33m[ TRIGGER ]\e[0m Idle threshold reached ($IDLE_MS ms). Checking presence..."
            
            # Step 1: Quick verification (Am I alone?)
            if ! "$HOWDY_WRAPPER_SCRIPT"; then
                echo -e "\e[1;31m[ ABSENCE ]\e[0m User not detected. Initiating LOCKdown."
                
                # Step 2: Full Lock Screen
                "$LOCK_LAUNCHER_SCRIPT"
                
                # Step 3: Post-Unlock Grace Period
                # After unlocking, the IDLE timer is still high until the user moves the mouse.
                # We sleep to give them time to resume activity.
                echo -e "\e[1;32m[ RESUME ]\e[0m Unlocked. Entering grace period (${UNLOCK_GRACE_PERIOD}s)."
                sleep "$UNLOCK_GRACE_PERIOD"
            else
                # User is present but idle (e.g. reading/watching)
                # We do nothing and let them be.
                sleep 5
            fi
        fi
    fi
    
    # Polling resolution: 1 second
    sleep 1
done
