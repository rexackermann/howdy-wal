#!/bin/bash
###############################################################################
#             Howdy-WAL - Smart Media Diagnostic (PipeWire Edition)           #
# --------------------------------------------------------------------------- #
# This diagnostic tool uses the modular media_check.sh (PipeWire/pw-dump).    #
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
echo -e "${CYAN}        Howdy-WAL - PipeWire Media Diagnostic       ${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. Inspect Audio Streams (via pw-dump)
echo -e "${YELLOW}[ 1/4 ] PipeWire Audio Streams:${NC}"
if ! command -v jq >/dev/null 2>&1; then
    echo -e "  ${RED}Error: jq is not installed. Data will be messy.${NC}"
    pw-dump | grep -E "application.name|state" | head -n 10
else
    # Extract name and state from Stream/Output/Audio nodes
    streams=$(pw-dump 2>/dev/null | jq -r '.[] | select(.info.props."media.class" == "Stream/Output/Audio") | "\(.info.props."application.name")|\(.info.state)"')
    
    if [ -n "$streams" ]; then
        while read -r line; do
            [ -z "$line" ] && continue
            name=$(echo "$line" | cut -d'|' -f1)
            state=$(echo "$line" | cut -d'|' -f2)
            if [ "$state" == "running" ]; then
                echo -e "  ${GREEN}✓${NC} $name ($state)"
            else
                echo -e "  ${YELLOW}-${NC} $name ($state)"
            fi
        done <<< "$streams"
    else
        echo -e "  ${RED}No active audio streams detected.${NC}"
    fi
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
