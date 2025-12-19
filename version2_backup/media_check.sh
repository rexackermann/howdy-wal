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

# --- HELPER: GET RUNNING AUDIO PIDs ---
get_running_audio_pids() {
    # Extract client IDs for running stream nodes, then map to PIDs
    local clients
    clients=$(pw-dump 2>/dev/null | jq -r '.[] | select(.info.props."media.class" == "Stream/Output/Audio" and .info.state == "running") | .info.props."client.id"')
    
    for client_id in $clients; do
        pw-dump 2>/dev/null | jq -r ".[] | select(.id == $client_id) | .info.props.\"application.process.id\"" 2>/dev/null
    done
}

# --- HELPER: GET AUDIO APPs (Standard Names) ---
get_audio_apps() {
    pw-dump 2>/dev/null | jq -r '.[] | select(.info.props."media.class" == "Stream/Output/Audio" and .info.state == "running") | .info.props | "\(.["application.id"]) \(.["application.name"])"' | tr '\n' ' '
}

# --- HELPER: GET INHIBITOR APPs ---
get_inhibitors() {
    local paths app reason
    paths=$(gdbus call --session --dest org.gnome.SessionManager --object-path /org/gnome/SessionManager --method org.gnome.SessionManager.GetInhibitors | grep -o "'/[^']*'")
    
    for path in $paths; do
        path=${path//\'/}
        app=$(gdbus call --session --dest org.gnome.SessionManager --object-path "$path" --method org.gnome.SessionManager.Inhibitor.GetAppId 2>/dev/null | cut -d"'" -f2)
        reason=$(gdbus call --session --dest org.gnome.SessionManager --object-path "$path" --method org.gnome.SessionManager.Inhibitor.GetReason 2>/dev/null | cut -d"'" -f2)
        echo "${app}|${reason}"
    done
}

# --- MAIN HEURISTIC ---
check_media() {
    # 0. Global Disable
    [ "$SMART_MEDIA" != "true" ] && return 1

    # 1. NEW: Focus-Aware Audio Check
    if [ -f "$FOCUS_DATA_FILE" ]; then
        local focused_pid running_pids
        focused_pid=$(jq -r '.focused.pid' "$FOCUS_DATA_FILE" 2>/dev/null)
        [ "$VERBOSE" = true ] && echo "DEBUG: Focused PID: $focused_pid" >> "$LOG_FILE"
        
        if [ -n "$focused_pid" ] && [ "$focused_pid" != "null" ]; then
            running_pids=$(get_running_audio_pids)
            [ "$VERBOSE" = true ] && echo "DEBUG: Running Audio PIDs: $running_pids" >> "$LOG_FILE"
            
            for rpid in $running_pids; do
                if [ "$rpid" == "$focused_pid" ]; then
                    [ "$VERBOSE" = true ] && echo "MEDIA BLOCKED: Focused app (PID $rpid) is playing audio." >> "$LOG_FILE"
                    return 0 # BLOCKED: Focused app is playing audio
                fi
            done
        fi
    fi

    # 2. Existing: Inhibitor Matching Fallback
    local audio_apps=$(get_audio_apps | tr '[:upper:]' '[:lower:]')
    local inhibitors=$(get_inhibitors)
    
    [ "$VERBOSE" = true ] && echo "DEBUG: Active Audio Apps: $audio_apps" >> "$LOG_FILE"
    [ "$VERBOSE" = true ] && echo "DEBUG: Active Session Inhibitors: $inhibitors" >> "$LOG_FILE"

    [ -z "$audio_apps" ] && return 1

    while read -r line; do
        [ -z "$line" ] && continue
        local inhibitor_app=$(echo "$line" | cut -d'|' -f1 | tr '[:upper:]' '[:lower:]')

        if echo "$IGNORE_INHIBITORS" | tr '[:upper:]' '[:lower:]' | grep -q "$inhibitor_app"; then
            [ "$VERBOSE" = true ] && echo "DEBUG: Ignoring inhibitor: $inhibitor_app" >> "$LOG_FILE"
            continue
        fi

        if [ "$MATCH_MEDIA_INHIBITOR" = true ]; then
            for a_app in $audio_apps; do
                if [[ "$inhibitor_app" == *"$a_app"* ]] || [[ "$a_app" == *"$inhibitor_app"* ]]; then
                    [ "$VERBOSE" = true ] && echo "MEDIA BLOCKED: Inhibitor '$inhibitor_app' matches audio app '$a_app'" >> "$LOG_FILE"
                    return 0 # BLOCKED: Inhibitor matches running audio app
                fi
            done
        else
            [ "$VERBOSE" = true ] && echo "MEDIA BLOCKED: Valid inhibitor found ('$inhibitor_app')" >> "$LOG_FILE"
            return 0 # BLOCKED: Any inhibitor (standard logic)
        fi
    done <<< "$inhibitors"

    return 1 # ALLOW LOCK
}

# Execute if called directly for testing, otherwise it's just sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_media
    exit $?
fi
