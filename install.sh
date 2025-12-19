#!/bin/bash
###############################################################################
# install_v2.sh - Installer for Howdy-WAL V2 (Non-TTY)                       #
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
echo -e "${CYAN}┃          Howdy-WAL V2 - Non-TTY Evolution          ┃${NC}"
echo -e "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"

# 1. Dependency Check
echo -e "\n${YELLOW}[ 1/4 ] Verifying V2 Dependencies...${NC}"
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
echo -e "\n${YELLOW}[ 2/4 ] Deploying Overlay Extension...${NC}"
EXT_ID="overlay-locker@howdy-wal.local"
SOURCE_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
EXT_SRC="$SOURCE_DIR/$EXT_ID"

if [ -d "$EXT_SRC" ]; then
    # Create local zip for proper installation
    TMP_ZIP=$(mktemp /tmp/howdy-wal-v2.XXXXXX.zip)
    (cd "$EXT_SRC" && zip -r "$TMP_ZIP" .) &>/dev/null
    
    gnome-extensions install --force "$TMP_ZIP" &>/dev/null
    rm "$TMP_ZIP"
    
    echo -e "  ${GREEN}✓${NC} Extension installed to ~/.local/share/gnome-shell/extensions/"
else
    echo -e "${RED}Error: Extension source not found.${NC}"
    exit 1
fi

# 3. Deploy Orchestrator & Helpers
echo -e "\n${YELLOW}[ 3/4 ] Deploying V2 Scripts...${NC}"
INSTALL_DIR="/opt/howdy-WAL"
sudo cp "$SOURCE_DIR/lock_v2.sh" "$INSTALL_DIR/"
sudo cp "$SOURCE_DIR/pam_verify.py" "$INSTALL_DIR/"
sudo chmod +x "$INSTALL_DIR/lock_v2.sh"
sudo chmod +x "$INSTALL_DIR/pam_verify.py"
echo -e "  ${GREEN}✓${NC} Scripts deployed to $INSTALL_DIR"

# 4. Final Instructions
echo -e "\n${YELLOW}[ 4/4 ] Finalizing...${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "${CYAN}          V2 Components Deployed Successfully!       ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "${YELLOW}CRITICAL STEP REQUIRED:${NC}"
echo -e "Because this is a GNOME Shell Extension, you MUST"
echo -e "${RED}LOG OUT and LOG BACK IN${NC} for GNOME to see the new plugin."
echo -e "\nAfter logging back in, you can test the new way with:"
echo -e "  ${CYAN}$INSTALL_DIR/lock_v2.sh${NC}"
echo -e "\n${GREEN}No more Bluetooth/Media drops! Enjoy the smooth lock.${NC}"
echo -e "====================================================\n"
