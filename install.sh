#!/bin/bash
###############################################################################
# install.sh - Hardened Howdy-WAL Installer (V2 Final)                        #
# --------------------------------------------------------------------------- #
# Deploys the GNOME Shell Overlay extensions, D-Bus orchestrators, and        #
# configures system security (PAM, Sudoers, WirePlumber).                     #
###############################################################################

# --- COLOR DEFINITIONS ---
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
CYAN='\e[1;36m'
NC='\e[0m'

echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${CYAN}┃          Howdy-WAL - Hardened V2 Evolution         ┃${NC}"
echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"

# 1. Prerequisites and Safety Checks
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: Please do NOT run as root/sudo directly.${NC}"
    echo "Run as your normal user. The script will request sudo where necessary."
    exit 1
fi

echo -e "\n${YELLOW}[ 1/7 ] Verifying System Dependencies...${NC}"
DEPENDENCIES=("zip" "gdbus" "python3" "pamtester" "howdy" "jq")
for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        echo -e "${RED}Error: Dependency '$dep' not found.${NC}"
        [ "$dep" == "howdy" ] && echo "Please install howdy first: https://github.com/boltgolt/howdy"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} $dep"
done

# Check for python3-pam
if ! python3 -c "import pam" &>/dev/null; then
    echo -e "${RED}Error: python3-pam not found.${NC}"
    echo "Please install it: sudo dnf install python3-pam"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} python3-pam"

# 2. File and Directory Deployment
echo -e "\n${YELLOW}[ 2/7 ] Deploying Core Components...${NC}"
INSTALL_DIR="/opt/howdy-WAL"
SOURCE_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"

sudo mkdir -p "$INSTALL_DIR"
sudo chown $USER:$USER "$INSTALL_DIR"

# Ensure log file exists and is writable
sudo touch "/var/log/howdy-wal.log"
sudo chmod 666 "/var/log/howdy-wal.log"
echo -e "  ${GREEN}✓${NC} Logging initialized at /var/log/howdy-wal.log"

# Copy all scripts
SCRIPTS=("lock.sh" "pam_verify.py" "config.sh" "howdy_wrapper.sh" "monitor.sh" "media_check.sh" "caffeine.sh" "faceauth" "00-howdy-WAL" "howdy-WAL.service" "lock_now.sh" "uninstall.sh")
for script in "${SCRIPTS[@]}"; do
    if [ -f "$SOURCE_DIR/$script" ]; then
        cp "$SOURCE_DIR/$script" "$INSTALL_DIR/"
        echo -e "  ${GREEN}✓${NC} $script deployed"
    else
        echo -e "  ${RED}Warning: $script missing from source!${NC}"
    fi
done
chmod +x "$INSTALL_DIR"/*.sh

# 3. PAM Configuration
echo -e "\n${YELLOW}[ 3/7 ] Configuring PAM Security Layer...${NC}"
if [ ! -f "/etc/pam.d/faceauth" ]; then
    sudo cp "$INSTALL_DIR/faceauth" /etc/pam.d/faceauth
    echo -e "  ${GREEN}✓${NC} /etc/pam.d/faceauth created."
fi

# Verify Howdy setup immediately
echo -e "${BLUE}[ TESTING ]${NC} Please look at the camera for a biometric test..."
if ! pamtester faceauth "$USER" authenticate; then
    echo -e "${RED}CRITICAL: Howdy verification failed.${NC}"
    echo "Ensure Howdy is trained for '$USER' before proceeding."
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Biometric verification confirmed."

# 4. Sudoers Integration
echo -e "\n${YELLOW}[ 4/7 ] Configuring Sudoers (Safe Bypass)...${NC}"
SUDOERS_TMP=$(mktemp)
sed "s|@USER@|$USER|g; s|@PATH@|$INSTALL_DIR|g" "$INSTALL_DIR/00-howdy-WAL" > "$SUDOERS_TMP"
sudo cp "$SUDOERS_TMP" "/etc/sudoers.d/00-howdy-WAL"
sudo chmod 0440 "/etc/sudoers.d/00-howdy-WAL"
rm "$SUDOERS_TMP"
echo -e "  ${GREEN}✓${NC} Sudoers policy installed."

# 5. WirePlumber Policy
echo -e "\n${YELLOW}[ 5/7 ] Deploying Bluetooth Persistence Policy...${NC}"
WP_CONF_DIR="/etc/wireplumber/wireplumber.conf.d"
if [ -f "$SOURCE_DIR/wp-bluetooth-persistence.conf" ]; then
    sudo mkdir -p "$WP_CONF_DIR"
    sudo cp "$SOURCE_DIR/wp-bluetooth-persistence.conf" "$WP_CONF_DIR/10-howdy-wal-bt.conf"
    echo -e "  ${GREEN}✓${NC} WirePlumber policy deployed."
fi

# 6. GNOME Shell Extensions
echo -e "\n${YELLOW}[ 6/7 ] Deploying Session-Native Overlays...${NC}"
EXTS=("overlay-locker@howdy-wal.local" "focus-exporter@howdy-wal.local")
for ext in "${EXTS[@]}"; do
    if [ -d "$SOURCE_DIR/$ext" ]; then
        TMP_ZIP=$(mktemp /tmp/howdy-wal-ext.XXXXXX.zip)
        (cd "$SOURCE_DIR/$ext" && zip -r "$TMP_ZIP" .) &>/dev/null
        gnome-extensions install --force "$TMP_ZIP" &>/dev/null
        rm "$TMP_ZIP"
        echo -e "  ${GREEN}✓${NC} $ext installed"
    fi
done

# Deploy and enable User Service
echo -e "\n${YELLOW}[ 7/7 ] Enabling Background Monitor Daemon...${NC}"
SERVICE_TMP=$(mktemp)
sed "s|@PATH@|$INSTALL_DIR|g" "$INSTALL_DIR/howdy-WAL.service" > "$SERVICE_TMP"
USER_SERVICE_DIR="$HOME/.config/systemd/user"
mkdir -p "$USER_SERVICE_DIR"
cp "$SERVICE_TMP" "$USER_SERVICE_DIR/howdy-WAL.service"
rm "$SERVICE_TMP"

systemctl --user daemon-reload
systemctl --user enable howdy-WAL.service
echo -e "  ${GREEN}✓${NC} howdy-WAL.service registered."

# --- FINALIZATION ---
echo -e "\n${GREEN}====================================================${NC}"
echo -e "${CYAN}          V2 Hardening & Parity Complete!            ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "${RED}CRITICAL: LOG OUT and LOG BACK IN NOW.${NC}"
echo -e "After logging in:"
echo -e "1. Run: ${CYAN}systemctl --user start howdy-WAL.service${NC}"
echo -e "2. Enable the extensions in GNOME Extensions."
echo -e "====================================================\n"
