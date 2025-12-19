#!/bin/bash
###############################################################################
#             Howdy-WAL - Smart Media Heuristic Tester (Hardened)             #
# --------------------------------------------------------------------------- #
# Use this to verify why the system is or isn't locking during media playback.#
###############################################################################

# Load config to get MATCH_MEDIA_INHIBITOR and IGNORE_INHIBITORS
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"

# --- COLOR DEFINITIONS ---
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
CYAN='\e[1;36m'
NC='\e[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${CYAN}        Howdy-WAL - Smart Media Diagnostic          ${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. Check Audio
echo -e "${YELLOW}[ 1/3 ] Audio Applications:${NC}"
AUDIO_APPS=$(pactl list sink-inputs 2>/dev/null | grep "application.name =" | cut -d'"' -f2 | tr '\n' ' ')
AUDIO_RUNNING=$(pactl list sink-inputs 2>/dev/null | grep -c "state: RUNNING")

if [ -n "$AUDIO_APPS" ]; then
    for app in $AUDIO_APPS; do
        if pactl list sink-inputs 2>/dev/null | grep -A 20 "application.name = \"$app\"" | grep -q "state: RUNNING"; then
             echo -e "  ${GREEN}✓${NC} $app (RUNNING)"
        else
             echo -e "  ${YELLOW}-${NC} $app (CORED/PAUSED)"
        fi
    done
else
    echo -e "  ${RED}No audio applications detected.${NC}"
fi

# 2. Check Inhibitors
echo -e "\n${YELLOW}[ 2/3 ] GNOME Session Inhibitors:${NC}"
PATHS=$(gdbus call --session --dest org.gnome.SessionManager --object-path /org/gnome/SessionManager --method org.gnome.SessionManager.GetInhibitors | grep -o "'/[^']*'")

INHIBITOR_APPS=""
if [ -n "$PATHS" ]; then
    for path in $PATHS; do
        path=${path//\'/}
        APP=$(gdbus call --session --dest org.gnome.SessionManager --object-path "$path" --method org.gnome.SessionManager.Inhibitor.GetAppId 2>/dev/null | cut -d"'" -f2)
        REASON=$(gdbus call --session --dest org.gnome.SessionManager --object-path "$path" --method org.gnome.SessionManager.Inhibitor.GetReason 2>/dev/null | cut -d"'" -f2)
        
        if echo "$IGNORE_INHIBITORS" | grep -q "$APP"; then
            echo -e "  ${RED}✖${NC} $APP (IGNORED: $REASON)"
        else
            echo -e "  ${GREEN}✓${NC} $APP ($REASON)"
            INHIBITOR_APPS="$INHIBITOR_APPS $APP"
        fi
    done
else
    echo -e "  ${RED}No inhibitors detected.${NC}"
fi

echo -e "${BLUE}----------------------------------------------------${NC}"

# 3. Decision Result
MATCH_FOUND=false
AUDIO_APPS_LOWER=$(echo "$AUDIO_APPS" | tr '[:upper:]' '[:lower:]')
INHIBITOR_APPS_LOWER=$(echo "$INHIBITOR_APPS" | tr '[:upper:]' '[:lower:]')

for app in $AUDIO_APPS_LOWER; do
    if echo "$INHIBITOR_APPS_LOWER" | grep -q "$app"; then
        MATCH_FOUND=true
        MATCH_APP=$app
        break
    fi
done

if [ "$SMART_MEDIA" != "true" ]; then
    echo -e "${YELLOW}>>> RESULT: FEATURE DISABLED <<<${NC}"
    echo -e "Reason: SMART_MEDIA is set to false in config.sh."
elif [ "$MATCH_FOUND" = true ]; then
    echo -e "${GREEN}>>> RESULT: SMART MEDIA ACTIVE <<<${NC}"
    echo -e "The monitor will ${CYAN}IGNORE${NC} idle triggers right now."
    echo -e "Reason: Match found between audio app and inhibitor: ${CYAN}$MATCH_APP${NC}"
elif [ "$MATCH_MEDIA_INHIBITOR" = "false" ] && [ -n "$INHIBITOR_APPS" ]; then
    echo -e "${GREEN}>>> RESULT: SMART MEDIA ACTIVE <<<${NC}"
    echo -e "The monitor will ${CYAN}IGNORE${NC} idle triggers right now."
    echo -e "Reason: Inhibitor detected and MATCH_MEDIA_INHIBITOR is false."
else
    echo -e "${YELLOW}>>> RESULT: STANDARD IDLE POLICY <<<${NC}"
    echo -e "The monitor will ${CYAN}LOCK${NC} the screen if the idle threshold is met."
    if [ -n "$AUDIO_APPS" ] && [ -n "$PATHS" ]; then
        echo -e "Reason: Audio is playing, but no matching inhibitor was found for the playing app."
    fi
fi
echo -e "${BLUE}====================================================${NC}"
