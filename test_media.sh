#!/bin/bash
###############################################################################
#             Howdy-WAL - Smart Media Heuristic Tester                        #
# --------------------------------------------------------------------------- #
# Use this to verify why the system is or isn't locking during media playback.#
###############################################################################

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
echo -en "${YELLOW}[ 1/2 ] Checking Audio Streams...${NC} "
AUDIO_RUNNING=$(pactl list sink-inputs 2>/dev/null | grep -c "state: RUNNING")

if [ "$AUDIO_RUNNING" -gt 0 ]; then
    echo -e "${GREEN}DETECTED ($AUDIO_RUNNING running streams)${NC}"
else
    echo -e "${RED}NONE (Silent)${NC}"
fi

# 2. Check Inhibitors
echo -en "${YELLOW}[ 2/2 ] Checking GNOME Inhibitors...${NC} "
INHIBITED=$(gdbus call --session \
                   --dest org.gnome.SessionManager \
                   --object-path /org/gnome/SessionManager \
                   --method org.gnome.SessionManager.IsInhibited 8 2>/dev/null \
                   | grep -o "true" | wc -l)

if [ "$INHIBITED" -gt 0 ]; then
    echo -e "${GREEN}ACTIVE (Media is in Foreground/Visible)${NC}"
else
    echo -e "${RED}INACTIVE (Media is Backgrounded or stopped)${NC}"
fi

echo -e "${BLUE}----------------------------------------------------${NC}"

# 3. Decision Result
if [ "$AUDIO_RUNNING" -gt 0 ] && [ "$INHIBITED" -gt 0 ]; then
    echo -e "${GREEN}>>> RESULT: SMART MEDIA ACTIVE <<<${NC}"
    echo -e "The monitor will ${CYAN}IGNORE${NC} idle triggers right now."
    echo -e "Reason: You are likely watching a video or presenting."
else
    echo -e "${YELLOW}>>> RESULT: STANDARD IDLE POLICY <<<${NC}"
    echo -e "The monitor will ${CYAN}LOCK${NC} the screen if the idle threshold is met."
    if [ "$AUDIO_RUNNING" -gt 0 ]; then
        echo -e "Note: Background music is playing, but it doesn't block locking."
    fi
fi
echo -e "${BLUE}====================================================${NC}"
