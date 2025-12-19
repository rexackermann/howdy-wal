#!/bin/bash
###############################################################################
# install.sh - Unified Howdy-WAL Installer (V2 Full Parity)                   #
# --------------------------------------------------------------------------- #
# Deploys the GNOME Shell Overlay extension and the D-Bus orchestrator.        #
###############################################################################

# --- COLOR DEFINITIONS ---
CYAN='\e[1;36m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
NC='\e[0m'

echo -e "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${CYAN}┃    Howdy-WAL - Unified Lock System (Full Parity)   ┃${NC}"
echo -e "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"

# 1. Dependency Check
echo -e "\n${YELLOW}[ 1/4 ] Verifying Dependencies...${NC}"
DEPENDENCIES=("zip" "gdbus" "python3" "pamtester")
for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        echo -e "${RED}Error: Dependency '$dep' not found.${NC}"
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

# 2. Deploy GNOME Shell Extension
echo -e "\n${YELLOW}[ 2/4 ] Deploying Overlay Extensions...${NC}"
SOURCE_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"

# Deploy Overlay Locker
EXT_ID="overlay-locker@howdy-wal.local"
if [ -d "$SOURCE_DIR/$EXT_ID" ]; then
    TMP_ZIP=$(mktemp /tmp/howdy-wal.XXXXXX.zip)
    (cd "$SOURCE_DIR/$EXT_ID" && zip -r "$TMP_ZIP" .) &>/dev/null
    gnome-extensions install --force "$TMP_ZIP" &>/dev/null
    rm "$TMP_ZIP"
    echo -e "  ${GREEN}✓${NC} overlay-locker extension installed"
fi

# Deploy Focus Exporter
EXT_ID_FOCUS="focus-exporter@howdy-wal.local"
if [ -d "$SOURCE_DIR/$EXT_ID_FOCUS" ]; then
    TMP_ZIP_FOCUS=$(mktemp /tmp/howdy-wal-focus.XXXXXX.zip)
    (cd "$SOURCE_DIR/$EXT_ID_FOCUS" && zip -r "$TMP_ZIP_FOCUS" .) &>/dev/null
    gnome-extensions install --force "$TMP_ZIP_FOCUS" &>/dev/null
    rm "$TMP_ZIP_FOCUS"
    echo -e "  ${GREEN}✓${NC} focus-exporter extension installed"
fi

# 3. Deploy Core Scripts & User Service
echo -e "\n${YELLOW}[ 3/4 ] Deploying Core Scripts & Services...${NC}"
INSTALL_DIR="/opt/howdy-WAL"
sudo mkdir -p "$INSTALL_DIR"
sudo chown $USER:$USER "$INSTALL_DIR"

# Copy all scripts
SCRIPTS=("lock.sh" "pam_verify.py" "config.sh" "howdy_wrapper.sh" "monitor.sh" "media_check.sh" "caffeine.sh")
for script in "${SCRIPTS[@]}"; do
    if [ -f "$SOURCE_DIR/$script" ]; then
        cp "$SOURCE_DIR/$script" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/$script"
        echo -e "  ${GREEN}✓${NC} $script deployed"
    fi
done

# Deploy and enable User Service
USER_SERVICE_DIR="$HOME/.config/systemd/user"
mkdir -p "$USER_SERVICE_DIR"
cp "$SOURCE_DIR/howdy-WAL.service" "$USER_SERVICE_DIR/"
systemctl --user daemon-reload
systemctl --user enable howdy-WAL.service
echo -e "  ${GREEN}✓${NC} howdy-WAL.service enabled (User Service)"

# 4. Final Instructions
echo -e "\n${YELLOW}[ 4/4 ] Finalizing...${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "${CYAN}          Howdy-WAL Deployed Successfully!           ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "${YELLOW}CRITICAL STEPS REQUIRED:${NC}"
echo -e "1. You MUST ${RED}LOG OUT and LOG BACK IN${NC} for GNOME extensions."
echo -e "2. Enable BOTH extensions in Extension Manager or Tweaks."
echo -e "3. Start the monitor service:"
echo -e "   ${CYAN}systemctl --user start howdy-WAL.service${NC}"
echo -e "\n${GREEN}Full Parity V2: Smooth, Smart, and Persistent.${NC}"
echo -e "====================================================\n"
