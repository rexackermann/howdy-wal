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

# Returns a space-separated list of application names playing audio
get_audio_apps() {
    pactl list sink-inputs 2>/dev/null | grep "application.name =" | cut -d'"' -f2 | tr '\n' ' '
}

# Returns a space-separated list of application IDs inhibiting idle
get_inhibitor_apps() {
    local paths apps app
    paths=$(gdbus call --session --dest org.gnome.SessionManager --object-path /org/gnome/SessionManager --method org.gnome.SessionManager.GetInhibitors | grep -o "'/[^']*'")
    apps=""
    for path in $paths; do
        path=${path//\'/}
        app=$(gdbus call --session --dest org.gnome.SessionManager --object-path "$path" --method org.gnome.SessionManager.Inhibitor.GetAppId 2>/dev/null | cut -d"'" -f2)
        [ -n "$app" ] && apps="$apps $app"
    done
    echo "$apps"
}

is_foreground_media() {
    local audio_apps inhibitor_apps
    
    # 1. Quick check for running audio
    if [ "$ONLY_RUNNING_AUDIO" = true ]; then
        if ! pactl list sink-inputs 2>/dev/null | grep -q "state: RUNNING"; then
            return 1 # No running audio
        fi
    else
        if ! pactl list sink-inputs 2>/dev/null | grep -q "sink-input"; then
            return 1 # No audio at all
        fi
    fi

    # 2. Check inhibitors
    audio_apps=$(get_audio_apps | tr '[:upper:]' '[:lower:]')
    inhibitor_apps=$(get_inhibitor_apps | tr '[:upper:]' '[:lower:]')

    # If matching is required, we look for an intersection
    if [ "$MATCH_MEDIA_INHIBITOR" = true ]; then
        for app in $audio_apps; do
            # Simple substring match for common app names
            if echo "$inhibitor_apps" | grep -q "$app"; then
                return 0 # Match found! (App playing audio is also inhibiting)
            fi
        done
        return 1 # No match found
    else
        # Standard logic: Is there ANY inhibitor that isn't on the ignore list?
        for app in $inhibitor_apps; do
            if ! echo "$IGNORE_INHIBITORS" | grep -q "$app"; then
                return 0 # Unignored inhibitor detected
            fi
        done
        return 1
    fi
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
        if is_foreground_media; then
            # Media is in foreground (Audio matches Inhibitor)
            # OR Standard inhibitor detected (if matching disabled)
            sleep 5
            continue
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
