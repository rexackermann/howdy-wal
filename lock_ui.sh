#!/bin/bash
###############################################################################
#             Howdy-WAL - Terminal Lock Interface                        #
# --------------------------------------------------------------------------- #
# This script handles the visual screensaver and the authentication flow.     #
# It is designed to be run on a dedicated TTY.                                #
#                                                                             #
# CAUTION: Terminating this script improperly might leave the TTY in a        #
# strange state. Use the built-in unlock mechanism.                           #
###############################################################################

# Determine script location and load central configuration
SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    echo "CRITICAL ERROR: config.sh not found in $SCRIPT_DIR"
    exit 1
fi

# --- TERMINAL INITIALIZATION ---
# Ensure ncurses and other TTY tools work correctly by setting TERM
export TERM="${TERM:-linux}"
if [ "$TERM" = "unknown" ]; then
    export TERM=linux
fi

# --- CLEANUP LOGIC ---
# Ensures children are killed and terminal is reset on exit.
cleanup() {
    echo "Initiating cleanup and unlocking..."
    pkill -P $$ >/dev/null 2>&1  # Kill background processes (Matrix/Visuals)
    sudo -k                      # Clear sudo timestamp for security
    setterm -cursor on           # Restore cursor
    clear
}
trap cleanup EXIT

# --- INITIALIZATION ---
clear
setterm -cursor off  # Hide the blinking cursor for maximum aesthetic

# --- AUTH FALLBACK: PASSWORD ---
# Since this script runs as root to maintain TTY control, we use pamtester
# to verify the user's password without relying on sudo's cached timestamp.
attempt_password_auth() {
    echo -e "\n\e[1;33m[ AUTH ]\e[0m Fallback: Password Authentication Required"
    echo -e "Target User: \e[1;36m${TARGET_USER:-$USER}\e[0m"
    
    if pamtester "$SUDO_SERVICE" "${TARGET_USER:-$USER}" authenticate; then
        echo -e "\e[1;32m[ SUCCESS ]\e[0m Identity Verified."
        return 0
    else
        echo -e "\e[1;31m[ ERROR ]\e[0m Incorrect Password."
        return 1
    fi
}

# --- MAIN LOOP ---
while true; do
    # 1. Start the Visual Engine (The "Screensaver") in the background
    echo "Launching visual engine: $VISUAL_ENGINE..."
    
    # Run the engine and capture its PID
    $VISUAL_ENGINE $VISUAL_ENGINE_ARGS &
    VE_PID=$!
    
    # 2. Wait for ANY key press
    # We use 'read' to wait for a single character.
    # We turn off echo and use raw mode to ensure we catch everything.
    stty -echo -icanon
    read -n 1 -s choice
    stty echo icanon
    
    # Kill the visual engine immediately
    kill "$VE_PID" 2>/dev/null
    wait "$VE_PID" 2>/dev/null
    
    # 3. Trigger Face Check
    clear
    echo -e "\e[1;34m[ SCANNING ]\e[0m Searching for verified user..."
    
    if "$HOWDY_WRAPPER_SCRIPT"; then
        echo -e "\e[1;32m[ VERIFIED ]\e[0m Welcome back, ${TARGET_USER:-$USER}."
        exit 0
    fi
    
    # 3. Interactive Auth Menu on Failure
    echo -e "\n\e[1;31m[ FAILED ]\e[0m No authorized presence detected."
    echo "----------------------------------------------------"
    echo -e "Options: [\e[1;36mR\e[0m]etry Face | [\e[1;36mP\e[0m]assword Auth | [\e[1;36mSpace\e[0m] Re-lock"
    echo "Waiting for input..."
    
    # Read input with timeout (default 10s from config)
    read -t "$MENU_TIMEOUT" -n 1 -s choice
    
    case "$choice" in
        p|P)
            if attempt_password_auth; then
                exit 0
            fi
            ;;
        r|R)
            echo -e "\n\e[1;34m[ SCANNING ]\e[0m Re-attempting facial verification..."
            if "$HOWDY_WRAPPER_SCRIPT"; then
                echo -e "\e[1;32m[ VERIFIED ]\e[0m Welcome back."
                exit 0
            else
                echo -e "\e[1;31m[ STILL FAILED ]\e[0m Authentication unsuccessful."
                sleep 1
            fi
            ;;
        *)
            # Timeout or any other key returns to screensaver
            echo "Returning to lock state..."
            ;;
    esac
done
