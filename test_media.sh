#!/bin/bash
###############################################################################
#             Howdy-WAL - Smart Media Diagnostic (Focus Aware)                #
# --------------------------------------------------------------------------- #
# This diagnostic tool uses media_check.sh (PipeWire + GNOME Extension).      #
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
echo -e "${CYAN}        Howdy-WAL - Focus-Aware Diagnostic          ${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. Focused Window Info
echo -e "${YELLOW}[ 1/5 ] GNOME Focused Window:${NC}"
if [ -f "$FOCUS_DATA_FILE" ]; then
    focused_pid=$(jq -r '.focused.pid' "$FOCUS_DATA_FILE" 2>/dev/null)
    focused_title=$(jq -r '.focused.title' "$FOCUS_DATA_FILE" 2>/dev/null)
    if [ -n "$focused_pid" ] && [ "$focused_pid" != "null" ]; then
        echo -e "  PID:   ${CYAN}$focused_pid${NC}"
        echo -e "  Title: ${CYAN}$focused_title${NC}"
    else
        echo -e "  ${RED}No focused window data found.${NC}"
    fi
else
    echo -e "  ${RED}Extension data file missing: $FOCUS_DATA_FILE${NC}"
fi

# 2. PipeWire Audio Check
echo -e "\n${YELLOW}[ 2/5 ] PipeWire Audio PIDs:${NC}"
running_pids=$(get_running_audio_pids)
if [ -n "$running_pids" ]; then
    for rpid in $running_pids; do
        comm=$(ps -p "$rpid" -o comm= 2>/dev/null)
        if [ "$rpid" == "$focused_pid" ]; then
            echo -e "  ${GREEN}✓${NC} $rpid ($comm) [FOCUSED]"
        else
            echo -e "  ${YELLOW}-${NC} $rpid ($comm) [BACKGROUND]"
        fi
    done
else
    echo -e "  ${RED}No running audio PIDs found.${NC}"
fi

# 3. GNOME Inhibitors
echo -e "\n${YELLOW}[ 3/5 ] GNOME Session Inhibitors:${NC}"
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

# 4. Final Decision
echo -e "${BLUE}----------------------------------------------------${NC}"
if check_media; then
    echo -e "${GREEN}>>> RESULT: SMART MEDIA BLOCKED LOCK <<<${NC}"
    echo -e "The monitor will ${CYAN}IGNORE${NC} idle triggers right now."
else
    echo -e "${YELLOW}>>> RESULT: STANDARD IDLE POLICY ACTIVE <<<${NC}"
    echo -e "The monitor will ${CYAN}LOCK${NC} if the idle threshold is met."
fi
echo -e "${BLUE}====================================================${NC}"
