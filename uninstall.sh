#!/bin/bash
###############################################################################
# uninstall.sh - Uninstaller for Howdy-WAL V2                                 #
# --------------------------------------------------------------------------- #
# Removes Howdy-WAL from /opt/howdy-WAL and cleans up all system integrations. #
###############################################################################

# --- COLOR DEFINITIONS ---
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
NC='\e[0m'

echo -e "${RED}====================================================${NC}"
echo -e "${YELLOW}          Howdy-WAL - System Uninstaller (V2)         ${NC}"
echo -e "${RED}====================================================${NC}"

INSTALL_DIR="/opt/howdy-WAL"

# 1. Stop User Service
echo -e "\n${YELLOW}[ 1/6 ] Stopping Background Monitor...${NC}"
systemctl --user stop howdy-WAL.service 2>/dev/null
systemctl --user disable howdy-WAL.service 2>/dev/null
rm -f "$HOME/.config/systemd/user/howdy-WAL.service"
systemctl --user daemon-reload
echo -e "  ${GREEN}✓${NC} Systemd user service removed."

# 2. Remove Sudoers Rule
echo -e "\n${YELLOW}[ 2/6 ] Removing Sudoers Policy...${NC}"
if [ -f "/etc/sudoers.d/00-howdy-WAL" ]; then
    sudo rm "/etc/sudoers.d/00-howdy-WAL"
    echo -e "  ${GREEN}✓${NC} Sudoers rule removed."
fi

# 3. Remove PAM Configuration
echo -e "\n${YELLOW}[ 3/6 ] Removing PAM Faceauth Layer...${NC}"
if [ -f "/etc/pam.d/faceauth" ]; then
    sudo rm "/etc/pam.d/faceauth"
    echo -e "  ${GREEN}✓${NC} /etc/pam.d/faceauth removed."
fi

# 4. Remove Shell Extensions
echo -e "\n${YELLOW}[ 4/6 ] Removing GNOME Extensions...${NC}"
EXTS=("overlay-locker@howdy-wal.local" "focus-exporter@howdy-wal.local")
for ext in "${EXTS[@]}"; do
    EXT_DEST="$HOME/.local/share/gnome-shell/extensions/$ext"
    if [ -d "$EXT_DEST" ]; then
        rm -rf "$EXT_DEST"
        echo -e "  ${GREEN}✓${NC} $ext removed."
    fi
done

# 5. Remove WirePlumber Policy
echo -e "\n${YELLOW}[ 5/6 ] Reverting WirePlumber Policy...${NC}"
WP_CONF="/etc/wireplumber/wireplumber.conf.d/10-howdy-wal-bt.conf"
if [ -f "$WP_CONF" ]; then
    sudo rm "$WP_CONF"
    echo -e "  ${GREEN}✓${NC} WirePlumber policy removed."
fi

# 6. Delete Installation Directory
echo -e "\n${YELLOW}[ 6/6 ] Deleting Core Files...${NC}"
if [ -d "$INSTALL_DIR" ]; then
    sudo rm -rf "$INSTALL_DIR"
    echo -e "  ${GREEN}✓${NC} $INSTALL_DIR deleted."
fi

echo -e "\n${GREEN}Cleanup complete. Howdy-WAL V2 has been uninstalled.${NC}\n"
