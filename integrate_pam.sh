#!/bin/bash
###############################################################################
# integrate_pam.sh - Native Howdy-into-GDM Installer                          #
# --------------------------------------------------------------------------- #
# This script safely adds pam_howdy.so to the GDM authentication stack.       #
###############################################################################

# --- COLORS ---
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
CYAN='\e[1;36m'
NC='\e[0m'

echo -e "${CYAN}--- Howdy GDM Integration Utility ---${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This utility MUST be run with sudo.${NC}"
    exit 1
fi

PAM_FILE="/etc/pam.d/gdm-password"

if [ ! -f "$PAM_FILE" ]; then
    echo -e "${RED}Error: $PAM_FILE not found. Are you on GNOME/GDM?${NC}"
    exit 1
fi

if grep -q "pam_howdy.so" "$PAM_FILE"; then
    echo -e "${GREEN}SUCCESS:${NC} Howdy is already integrated into GDM."
    exit 0
fi

echo -e "${YELLOW}Injecting Howdy into $PAM_FILE...${NC}"

# Backup
cp "$PAM_FILE" "${PAM_FILE}.bak"

# Inject 'auth sufficient pam_howdy.so' at the top of the auth stack
# Fedora's gdm-password usually starts with 'auth [success=done ignore=ignore default=bad] pam_selinux_permit.so'
# or similar. We'll put it right after the first line.
sed -i '2i auth    sufficient      pam_howdy.so' "$PAM_FILE"

if grep -q "pam_howdy.so" "$PAM_FILE"; then
    echo -e "${GREEN}SUCCESS:${NC} Howdy integrated. Camera will now fire on lock screen interact."
else
    echo -e "${RED}Error:${NC} Injection failed."
    exit 1
fi
