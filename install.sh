#!/bin/bash
###############################################################################
# install.sh - Final Stabilized Installer (V2 + V1 Component Parity)          #
# --------------------------------------------------------------------------- #
# Deploys the GNOME Overlays and all biometric/media logic layers.            #
###############################################################################

# --- COLOR DEFINITIONS ---
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
CYAN='\e[1;36m'
NC='\e[0m'

echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${CYAN}┃     Howdy-WAL - Final Stabilization & Parity       ┃${NC}"
echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"

# 1. Verification
echo -e "\n${YELLOW}[ 1/7 ] Checking System Prerequisites...${NC}"
DEPENDENCIES=("zip" "gdbus" "python3" "pamtester" "howdy" "jq")
for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        echo -e "${RED}Error: '$dep' missing.${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} $dep"
done

# 2. Filesystem Setup
echo -e "\n${YELLOW}[ 2/7 ] Initializing /opt/howdy-WAL...${NC}"
INSTALL_DIR="/opt/howdy-WAL"
SOURCE_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"

sudo mkdir -p "$INSTALL_DIR"
sudo chown $USER:$USER "$INSTALL_DIR"

sudo touch "/var/log/howdy-wal.log"
sudo chmod 666 "/var/log/howdy-wal.log"

SCRIPTS=("lock.sh" "pam_verify.py" "config.sh" "howdy_wrapper.sh" "monitor.sh" "media_check.sh" "caffeine.sh" "faceauth" "00-howdy-WAL" "howdy-WAL.service" "lock_now.sh" "uninstall.sh")
for script in "${SCRIPTS[@]}"; do
    if [ -f "$SOURCE_DIR/$script" ]; then
        cp "$SOURCE_DIR/$script" "$INSTALL_DIR/"
        echo -e "  ${GREEN}✓${NC} $script deployed"
    fi
done
chmod +x "$INSTALL_DIR"/*.sh

# 3. System Policies
echo -e "\n${YELLOW}[ 3/7 ] Deploying Security Policies...${NC}"
sudo cp "$INSTALL_DIR/faceauth" /etc/pam.d/faceauth
SUDOERS_TMP=$(mktemp)
sed "s|@USER@|$USER|g; s|@PATH@|$INSTALL_DIR|g" "$INSTALL_DIR/00-howdy-WAL" > "$SUDOERS_TMP"
sudo cp "$SUDOERS_TMP" "/etc/sudoers.d/00-howdy-WAL"
sudo chmod 0440 "/etc/sudoers.d/00-howdy-WAL"
rm "$SUDOERS_TMP"
echo -e "  ${GREEN}✓${NC} PAM and Sudoers policies updated."

# 4. Bluetooth Persistence
echo -e "\n${YELLOW}[ 4/7 ] Deploying WirePlumber Logic...${NC}"
WP_CONF_DIR="/etc/wireplumber/wireplumber.conf.d"
if [ -f "$SOURCE_DIR/wp-bluetooth-persistence.conf" ]; then
    sudo mkdir -p "$WP_CONF_DIR"
    sudo cp "$SOURCE_DIR/wp-bluetooth-persistence.conf" "$WP_CONF_DIR/10-howdy-wal-bt.conf"
    echo -e "  ${GREEN}✓${NC} WirePlumber persistence active."
fi

# 5. GNOME Shell Extensions (The Core Overlays)
echo -e "\n${YELLOW}[ 5/7 ] Installing/Refreshing GNOME Extensions...${NC}"
EXTS=("overlay-locker@howdy-wal.local" "focus-exporter@howdy-wal.local")
for ext in "${EXTS[@]}"; do
    if [ -d "$SOURCE_DIR/$ext" ]; then
        # Properly install via zip to ensure GNOME registers them
        TMP_ZIP=$(mktemp /tmp/howdy-ext.XXXXXX.zip)
        (cd "$SOURCE_DIR/$ext" && zip -r "$TMP_ZIP" .) &>/dev/null
        gnome-extensions install --force "$TMP_ZIP" &>/dev/null
        rm "$TMP_ZIP"
        echo -e "  ${GREEN}✓${NC} $ext updated."
    fi
done

# 6. Service Registration
echo -e "\n${YELLOW}[ 6/7 ] Starting Background Monitor...${NC}"
SERVICE_TMP=$(mktemp)
sed "s|@PATH@|$INSTALL_DIR|g" "$INSTALL_DIR/howdy-WAL.service" > "$SERVICE_TMP"
USER_SERVICE_DIR="$HOME/.config/systemd/user"
mkdir -p "$USER_SERVICE_DIR"
cp "$SERVICE_TMP" "$USER_SERVICE_DIR/howdy-WAL.service"
rm "$SERVICE_TMP"

systemctl --user daemon-reload
systemctl --user enable howdy-WAL.service
echo -e "  ${GREEN}✓${NC} howdy-WAL.service registered as user daemon."

# 7. Final Stabilization Routine
echo -e "\n${YELLOW}[ 7/7 ] Final Stabilization...${NC}"
# Attempt to restart extensions without logout
for ext in "${EXTS[@]}"; do
    gnome-extensions disable "$ext" &>/dev/null
    gnome-extensions enable "$ext" &>/dev/null
done
echo -e "  ${GREEN}✓${NC} Extensions toggled."

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${CYAN}      Parity Restoration & Stabilization Complete    ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "${YELLOW}IMPORTANT: If the screen is still black, press ESC 3 times.${NC}"
echo -e "Start the daemon: ${CYAN}systemctl --user start howdy-WAL.service${NC}"
echo -e "====================================================\n"
