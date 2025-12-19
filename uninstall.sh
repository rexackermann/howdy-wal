#!/bin/bash
###############################################################################
#             Howdy Autolock - System Uninstaller                             #
# --------------------------------------------------------------------------- #
# Removes Howdy Autolock from /opt/howdy-autolock and cleans up integrations. #
###############################################################################

# --- COLOR DEFINITIONS ---
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
NC='\e[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${YELLOW}          Howdy Autolock - System Uninstaller       ${NC}"
echo -e "${BLUE}====================================================${NC}"

INSTALL_DIR="/opt/howdy-autolock"

# 1. Stop Service
echo -e "\n${YELLOW}[ 1/4 ] Stopping & Disabling Service...${NC}"
systemctl --user stop howdy-autolock.service 2>/dev/null
systemctl --user disable howdy-autolock.service 2>/dev/null
rm -f "$HOME/.config/systemd/user/howdy-autolock.service"
systemctl --user daemon-reload
echo -e "  ${GREEN}✓${NC} Systemd service removed."

# 2. Remove Sudoers Rule
echo -e "\n${YELLOW}[ 2/4 ] Removing Sudoers Rule...${NC}"
if [ -f "/etc/sudoers.d/00-howdy-autolock" ]; then
    sudo rm "/etc/sudoers.d/00-howdy-autolock"
    echo -e "  ${GREEN}✓${NC} Sudoers rule removed."
fi

# 3. Remove PAM Config
echo -e "\n${YELLOW}[ 3/4 ] Removing PAM Configuration...${NC}"
if [ -f "/etc/pam.d/faceauth" ]; then
    sudo rm "/etc/pam.d/faceauth"
    echo -e "  ${GREEN}✓${NC} /etc/pam.d/faceauth removed."
fi

# 4. Delete Project Files
echo -e "\n${YELLOW}[ 4/4 ] Deleting Installation Directory...${NC}"
if [ -d "$INSTALL_DIR" ]; then
    sudo rm -rf "$INSTALL_DIR"
    echo -e "  ${GREEN}✓${NC} $INSTALL_DIR deleted."
fi

echo -e "\n${GREEN}Cleanup complete. Howdy Autolock has been uninstalled.${NC}\n"
