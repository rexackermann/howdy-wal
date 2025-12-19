#!/bin/bash
###############################################################################
#             Howdy Autolock - System Installer                               #
# --------------------------------------------------------------------------- #
# Installs Howdy Autolock to /opt/howdy-autolock and configures system        #
# integrations (PAM, Sudoers, Systemd).                                       #
#                                                                             #
# MUST BE RUN AS REGULAR USER (will prompt for sudo).                         #
###############################################################################

# --- COLOR DEFINITIONS ---
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
CYAN='\e[1;36m'
NC='\e[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${CYAN}          Howdy Autolock - System Installer         ${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. Dependency Check
echo -e "\n${YELLOW}[ 1/6 ] Checking Dependencies...${NC}"
DEPS=("howdy" "pamtester" "gdbus" "openvt" "fgconsole" "sed" "awk")
for dep in "${DEPS[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        echo -e "${RED}Error: Dependency '$dep' not found.${NC}"
        if [ "$dep" == "howdy" ]; then
            echo -e "${YELLOW}Howdy is usually not in official repos.${NC}"
            echo "Please follow the official guide at: https://github.com/boltgolt/howdy"
            echo "Or for Fedora, check the 'principis/howdy' COPR."
        fi
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} $dep"
done

# 2. Prerequisites & Root Check
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: Please do NOT run as root/sudo directly.${NC}"
    echo "Run as your normal user. The script will request sudo where necessary."
    exit 1
fi

INSTALL_DIR="/opt/howdy-autolock"
CURRENT_USER="$USER"
SOURCE_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"

# Load current config to check for the Visual Engine
source "$SOURCE_DIR/config.sh"
if ! command -v "$VISUAL_ENGINE" &> /dev/null; then
    echo -e "${RED}Warning: Visual Engine '$VISUAL_ENGINE' not found in path.${NC}"
    echo -e "You might want to install it or change VISUAL_ENGINE in config.sh later."
fi

# 3. Directory Creation & File Transfer
echo -e "\n${YELLOW}[ 2/6 ] Deploying to $INSTALL_DIR...${NC}"
sudo mkdir -p "$INSTALL_DIR"
echo "Copying scripts..."
sudo cp "$SOURCE_DIR"/*.sh "$INSTALL_DIR/"
sudo cp "$SOURCE_DIR/faceauth" "$INSTALL_DIR/"
sudo cp "$SOURCE_DIR/howdy-autolock.service" "$INSTALL_DIR/"
sudo cp "$SOURCE_DIR/00-howdy-autolock" "$INSTALL_DIR/"
sudo cp "$SOURCE_DIR/LICENSE" "$INSTALL_DIR/"

# Set permissions
sudo chmod +x "$INSTALL_DIR"/*.sh
sudo chown -R root:root "$INSTALL_DIR"

# 4. PAM Configuration
echo -e "\n${YELLOW}[ 3/6 ] Configuring PAM (biometric auth)...${NC}"
if [ ! -f "/etc/pam.d/faceauth" ]; then
    sudo cp "$INSTALL_DIR/faceauth" /etc/pam.d/faceauth
    echo -e "  ${GREEN}✓${NC} /etc/pam.d/faceauth created."
else
    echo "  - /etc/pam.d/faceauth already exists."
fi

# Verify Howdy setup
echo -e "${BLUE}[ TESTING ]${NC} Please look at the camera for a quick verification test..."
if ! pamtester faceauth "$CURRENT_USER" authenticate; then
    echo -e "${YELLOW}Warning: Basic face verification failed.${NC}"
    echo "Make sure Howdy is trained and working before relying on this lockscreen."
else
    echo -e "  ${GREEN}✓${NC} Verification successful."
fi

# 5. Sudoers Integration
echo -e "\n${YELLOW}[ 4/6 ] Configuring Sudoers (passwordless lock)...${NC}"
SUDOERS_TMP=$(mktemp)
sed "s|@USER@|$CURRENT_USER|g; s|@PATH@|$INSTALL_DIR|g" "$INSTALL_DIR/00-howdy-autolock" > "$SUDOERS_TMP"
sudo cp "$SUDOERS_TMP" "/etc/sudoers.d/00-howdy-autolock"
sudo chmod 0440 "/etc/sudoers.d/00-howdy-autolock"
rm "$SUDOERS_TMP"
echo -e "  ${GREEN}✓${NC} Sudoers rule installed."

# 6. Systemd Service Registration
echo -e "\n${YELLOW}[ 5/6 ] Registering User Service...${NC}"
SERVICE_TMP=$(mktemp)
sed "s|@PATH@|$INSTALL_DIR|g" "$INSTALL_DIR/howdy-autolock.service" > "$SERVICE_TMP"
USER_SERVICE_DIR="$HOME/.config/systemd/user"
mkdir -p "$USER_SERVICE_DIR"
cp "$SERVICE_TMP" "$USER_SERVICE_DIR/howdy-autolock.service"
rm "$SERVICE_TMP"

systemctl --user daemon-reload
systemctl --user enable --now howdy-autolock.service
echo -e "  ${GREEN}✓${NC} Systemd user service enabled and started."

echo -e "\n${YELLOW}[ 6/6 ] Finalizing...${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}          Installation Successful!                  ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "The project is installed in ${CYAN}$INSTALL_DIR${NC}"
echo -e "You can now safely delete the source directory."
echo -e "\nTo verify the lock, run:"
echo -e "  ${CYAN}$INSTALL_DIR/lock_screen.sh${NC}"
echo -e "\nTo toggle Caffeine mode, run:"
echo -e "  ${CYAN}$INSTALL_DIR/caffeine.sh${NC}"
echo -e "====================================================\n"
