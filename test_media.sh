#!/bin/bash
###############################################################################
#             Howdy-WAL - Smart Media Diagnostic (Modular)                    #
# --------------------------------------------------------------------------- #
# This diagnostic tool uses the same media_check.sh logic as the monitor.     #
###############################################################################

# Load config and core module
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"
[ -f "$SCRIPT_DIR/media_check.sh" ] && source "$SCRIPT_DIR/media_check.sh"

# --- COLOR DEFINITIONS ---
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
CYAN='\e[1;36m'
NC='\e[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${CYAN}        Howdy-WAL - Core Media Diagnostic           ${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. Inspect Audio Streams
echo -e "${YELLOW}[ 1/4 ] Audio Applications:${NC}"
AUDIO_APPS=$(get_audio_apps)
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

# 2. Inspect Inhibitors
echo -e "\n${YELLOW}[ 2/4 ] GNOME Session Inhibitors:${NC}"
INHIBITORS=$(get_inhibitors)

if [ -n "$INHIBITORS" ]; then
    while read -r line; do
        [ -z "$line" ] && continue
        app=$(echo "$line" | cut -d'|' -f1)
        reason=$(echo "$line" | cut -d'|' -f2)
        
        if echo "$IGNORE_INHIBITORS" | grep -q "$app"; then
            echo -e "  ${RED}✖${NC} $app (IGNORED: $reason)"
        else
            echo -e "  ${GREEN}✓${NC} $app ($reason)"
        fi
    done <<< "$INHIBITORS"
else
    echo -e "  ${RED}No inhibitors detected.${NC}"
fi

# 3. Policy Settings
echo -e "\n${YELLOW}[ 3/4 ] Configuration Policy:${NC}"
echo -e "  MATCH_MEDIA_INHIBITOR: ${CYAN}${MATCH_MEDIA_INHIBITOR}${NC}"
echo -e "  ONLY_RUNNING_AUDIO:    ${CYAN}${ONLY_RUNNING_AUDIO}${NC}"
echo -e "  IGNORE_INHIBITORS:     ${CYAN}${IGNORE_INHIBITORS}${NC}"

echo -e "${BLUE}----------------------------------------------------${NC}"

# 4. Final Decision
if check_media; then
    echo -e "${GREEN}>>> RESULT: SMART MEDIA BLOCKED LOCK <<<${NC}"
    echo -e "The monitor will ${CYAN}IGNORE${NC} idle triggers right now."
else
    echo -e "${YELLOW}>>> RESULT: STANDARD IDLE POLICY ACTIVE <<<${NC}"
    echo -e "The monitor will ${CYAN}LOCK${NC} if the idle threshold is met."
fi
echo -e "${BLUE}====================================================${NC}"
