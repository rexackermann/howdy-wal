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
# Uses pw-dump and jq to extract application IDs and names from active streams
get_audio_apps() {
    if ! command -v jq >/dev/null 2>&1; then
        # Fallback to a crude grep if jq is missing (not ideal)
        pw-dump 2>/dev/null | grep -E "application.name|application.id" | cut -d'"' -f4 | tr '\n' ' '
        return
    fi

    # Extract application.id and application.name from nodes that are Stream/Output/Audio
    # We only care about nodes that are NOT suspended if ONLY_RUNNING_AUDIO is true
    if [ "$ONLY_RUNNING_AUDIO" = true ]; then
        pw-dump 2>/dev/null | jq -r '.[] | select(.info.props."media.class" == "Stream/Output/Audio" and .info.state == "running") | .info.props | "\(.["application.id"]) \(.["application.name"])"' | tr '\n' ' '
    else
        pw-dump 2>/dev/null | jq -r '.[] | select(.info.props."media.class" == "Stream/Output/Audio") | .info.props | "\(.["application.id"]) \(.["application.name"])"' | tr '\n' ' '
    fi
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
    # 0. Dependency Check
    if ! command -v pw-dump >/dev/null 2>&1; then
        # Fallback to pactl if pw-dump is missing
        pactl list sink-inputs 2>/dev/null | grep -q "sink-input" && return 0 || return 1
    fi

    # 1. Global Disable
    [ "$SMART_MEDIA" != "true" ] && return 1

    # 2. Extract active audio apps and inhibitors
    local audio_apps=$(get_audio_apps | tr '[:upper:]' '[:lower:]')
    local inhibitors=$(get_inhibitors)
    
    # If no audio is detected, we don't care about inhibitors for media logic
    [ -z "$audio_apps" ] && return 1

    # 3. Decision Logic
    local match_found=false
    
    while read -r line; do
        [ -z "$line" ] && continue
        local inhibitor_app=$(echo "$line" | cut -d'|' -f1 | tr '[:upper:]' '[:lower:]')

        # Skip ignored inhibitors (general purpose caffeine, etc)
        if echo "$IGNORE_INHIBITORS" | tr '[:upper:]' '[:lower:]' | grep -q "$inhibitor_app"; then
            continue
        fi

        # If matching is enabled, we need to find the app in the audio list
        if [ "$MATCH_MEDIA_INHIBITOR" = true ]; then
            # We look for a cross-match between inhibitor AppID and pw-dump app IDs/names
            for a_app in $audio_apps; do
                if [[ "$inhibitor_app" == *"$a_app"* ]] || [[ "$a_app" == *"$inhibitor_app"* ]]; then
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
