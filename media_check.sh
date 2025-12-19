#!/bin/bash
###############################################################################
#             Howdy-WAL - Media Interaction Module                            #
# --------------------------------------------------------------------------- #
# This script determines if the system should skip an idle lock based on      #
# active media playback and foreground status.                                #
#                                                                             #
# Returns 0 (Success) -> Media detected, SKIP lock.                           #
# Returns 1 (Failure) -> No foreground media, PROCEED with lock.              #
###############################################################################

# Determine script location and load central configuration
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"

# --- HELPER: GET AUDIO APPs ---
# Extracts application.name and application.id from pactl
get_audio_apps() {
    pactl list sink-inputs 2>/dev/null | grep -E "application.name =|application.id =" | cut -d'"' -f2 | tr '\n' ' '
}

# --- HELPER: GET INHIBITOR APPs ---
# Interrogates GNOME Session Manager for active idle inhibitors
get_inhibitors() {
    local paths app reason
    paths=$(gdbus call --session --dest org.gnome.SessionManager --object-path /org/gnome/SessionManager --method org.gnome.SessionManager.GetInhibitors | grep -o "'/[^']*'")
    
    for path in $paths; do
        path=${path//\'/}
        app=$(gdbus call --session --dest org.gnome.SessionManager --object-path "$path" --method org.gnome.SessionManager.Inhibitor.GetAppId 2>/dev/null | cut -d"'" -f2)
        reason=$(gdbus call --session --dest org.gnome.SessionManager --object-path "$path" --method org.gnome.SessionManager.Inhibitor.GetReason 2>/dev/null | cut -d"'" -f2)
        
        # Output as "AppID|Reason"
        echo "${app}|${reason}"
    done
}

# --- MAIN HEURISTIC ---
check_media() {
    # 0. Global Disable
    [ "$SMART_MEDIA" != "true" ] && return 1

    # 1. Quick Audio Presence Check
    local audio_present
    if [ "$ONLY_RUNNING_AUDIO" = true ]; then
        audio_present=$(pactl list sink-inputs 2>/dev/null | grep -c "state: RUNNING")
    else
        audio_present=$(pactl list sink-inputs 2>/dev/null | grep -c "sink-input")
    fi
    [ "$audio_present" -eq 0 ] && return 1

    # 2. Extract active audio apps and inhibitors
    local audio_apps=$(get_audio_apps | tr '[:upper:]' '[:lower:]')
    local inhibitors=$(get_inhibitors)
    
    # 3. Decision Logic
    local match_found=false
    
    while read -r line; do
        [ -z "$line" ] && continue
        local app=$(echo "$line" | cut -d'|' -f1 | tr '[:upper:]' '[:lower:]')
        local reason=$(echo "$line" | cut -d'|' -f2 | tr '[:upper:]' '[:lower:]')

        # Skip ignored inhibitors (general purpose caffeine, etc)
        if echo "$IGNORE_INHIBITORS" | tr '[:upper:]' '[:lower:]' | grep -q "$app"; then
            continue
        fi

        # If matching is enabled, we need to find the app in the audio list
        if [ "$MATCH_MEDIA_INHIBITOR" = true ]; then
            # We look for a cross-match between inhibitor AppID and pactl app names
            for a_app in $audio_apps; do
                if [[ "$app" == *"$a_app"* ]] || [[ "$a_app" == *"$app"* ]]; then
                    match_found=true
                    break 2
                fi
            done
        else
            # Generic matching disabled: ANY unignored inhibitor + audio = block
            match_found=true
            break
        fi
    done <<< "$inhibitors"

    if [ "$match_found" = true ]; then
        return 0 # BLOCK LOCK
    else
        return 1 # ALLOW LOCK
    fi
}

# Execute if called directly for testing, otherwise it's just sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_media
    exit $?
fi
