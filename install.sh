#!/bin/bash
###############################################################################
# install.sh - Howdy-WAL Native Pivot (Final Stabilization)                   #
# --------------------------------------------------------------------------- #
# This installer switches the locking mechanism to the native GNOME lock      #
# screen, eliminating custom extension bugs while keeping all smart features. #
###############################################################################

# --- COLORS ---
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
CYAN='\e[1;36m'
NC='\e[0m'

echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${CYAN}┃        Howdy-WAL - Native Stability Pivot         ┃${NC}"
echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"

# 1. Dependency Check
echo -e "\n${YELLOW}[ 1/6 ] Verifying Dependencies...${NC}"
DEPENDENCIES=("zip" "gdbus" "python3" "pamtester" "howdy" "jq")
for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        echo -e "${RED}Error: '$dep' missing.${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} $dep"
done

# 2. Cleanup Old Logic
echo -e "\n${YELLOW}[ 2/6 ] Decommissioning Custom Extensions...${NC}"
OLD_EXT="overlay-locker@howdy-wal.local"
if [ -d "$HOME/.local/share/gnome-shell/extensions/$OLD_EXT" ]; then
    gnome-extensions unregister "$OLD_EXT" &>/dev/null
    rm -rf "$HOME/.local/share/gnome-shell/extensions/$OLD_EXT"
    echo -e "  ${GREEN}✓${NC} $OLD_EXT removed"
fi

# 3. Deploy Intelligence Layer (Focus Exporter)
echo -e "\n${YELLOW}[ 3/6 ] Deploying Media Focus Exporter (V1 Logic)...${NC}"
EXT_ID="focus-exporter@howdy-wal.local"
SOURCE_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"

if [ -d "$SOURCE_DIR/$EXT_ID" ]; then
    TMP_ZIP=$(mktemp /tmp/howdy-focus.XXXXXX.zip)
    (cd "$SOURCE_DIR/$EXT_ID" && zip -r "$TMP_ZIP" .) &>/dev/null
    gnome-extensions install --force "$TMP_ZIP" &>/dev/null
    rm "$TMP_ZIP"
    echo -e "  ${GREEN}✓${NC} Focus Exporter installed"
else
    echo -e "${RED}Error: Extension source folder $EXT_ID not found!${NC}"
    exit 1
fi

# 4. Deploy Scripts & Services
echo -e "\n${YELLOW}[ 4/6 ] Deploying Scripts to /opt/howdy-WAL...${NC}"
INSTALL_DIR="/opt/howdy-WAL"
sudo mkdir -p "$INSTALL_DIR"
sudo chown $USER:$USER "$INSTALL_DIR"

SCRIPTS=("lock.sh" "pam_verify.py" "config.sh" "howdy_wrapper.sh" "monitor.sh" "media_check.sh" "caffeine.sh" "faceauth" "00-howdy-WAL" "howdy-WAL.service" "lock_now.sh" "uninstall.sh" "integrate_pam.sh")
for script in "${SCRIPTS[@]}"; do
    if [ -f "$SOURCE_DIR/$script" ]; then
        cp "$SOURCE_DIR/$script" "$INSTALL_DIR/"
        echo -e "  ${GREEN}✓${NC} $script deployed"
    fi
done
chmod +x "$INSTALL_DIR"/*.sh

# 5. Bluetooth/Audio Persistence
echo -e "\n${YELLOW}[ 5/6 ] Configuring Audio Persistence...${NC}"
WP_CONF_DIR="/etc/wireplumber/wireplumber.conf.d"
if [ -f "$SOURCE_DIR/wp-bluetooth-persistence.conf" ]; then
    sudo mkdir -p "$WP_CONF_DIR"
    sudo cp "$SOURCE_DIR/wp-bluetooth-persistence.conf" "$WP_CONF_DIR/10-howdy-wal-bt.conf"
    echo -e "  ${GREEN}✓${NC} WirePlumber policy active."
fi

# 6. Service Management
echo -e "\n${YELLOW}[ 6/6 ] Finalizing Background Daemon...${NC}"
SERVICE_TMP=$(mktemp)
sed "s|@PATH@|$INSTALL_DIR|g" "$INSTALL_DIR/howdy-WAL.service" > "$SERVICE_TMP"
USER_SERVICE_DIR="$HOME/.config/systemd/user"
mkdir -p "$USER_SERVICE_DIR"
cp "$SERVICE_TMP" "$USER_SERVICE_DIR/howdy-WAL.service"
rm "$SERVICE_TMP"

systemctl --user daemon-reload
systemctl --user enable howdy-WAL.service

# Final Stabilization
gnome-extensions enable "$EXT_ID" &>/dev/null

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${CYAN}      Native Stability Pivot Deployment Complete     ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "${YELLOW}FINAL STEPS FOR BIOMETRIC LOCK SCREEN:${NC}"
echo -e "1. Run the PAM integration utility (makes face scan work on lock screen):"
echo -e "   ${CYAN}sudo $INSTALL_DIR/integrate_pam.sh${NC}"
echo -e "2. Start the brain:"
echo -e "   ${CYAN}systemctl --user start howdy-WAL.service${NC}"
echo -e "\n${GREEN}No more custom extensions. No more black screen bugs.${NC}"
echo -e "====================================================\n"
