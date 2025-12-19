#!/bin/bash
###############################################################################
#             Howdy-Wal - Central Configuration File                     #
# --------------------------------------------------------------------------- #
# This file contains all the tunable variables for the howdy-wal system.       #
# Changes here will be reflected across all components.                       #
###############################################################################

# --- INSTALLATION SETTINGS ---
# The path where the project is installed. 
# For system-wide use, this is typically /opt/howdy-wal
INSTALL_DIR="/opt/howdy-wal"

# --- TIMING & BEHAVIOR ---
# Idle time in milliseconds before triggering the lock (10000 = 10s)
IDLE_THRESHOLD_MS=10000

# Grace period (seconds) after unlocking before the monitor resumes checking
# This prevents immediate re-locking if the system hasn't registered activity yet.
UNLOCK_GRACE_PERIOD=30

# Timeout (seconds) for the interactive auth menu (Password/Retry)
MENU_TIMEOUT=10

# --- TTY ENFORCEMENT ---
# The Virtual Terminal used for the lock screen.
LOCK_VT=9

# Emergency Recovery TTY.
# If you switch to this VT, the Sticky TTY loop will NOT pull you back.
# Use this for debugging or if you get stuck. Set to 0 to disable.
EMERGENCY_VT=3

# --- CAFFEINE MODE ---
# Path to the trigger file that pauses auto-lock.
CAFFEINE_FILE="/tmp/howdy_caffeine"

# --- AUTHENTICATION SERVICES ---
# The PAM service used for face verification (configured in /etc/pam.d/)
PAM_SERVICE="faceauth"

# THE PAM service used for password fallback (usually 'sudo' or 'login')
SUDO_SERVICE="sudo"

# --- VISUAL ENGINES ---
# The command used to generate the screensaver effect.
# You can replace this with cmatrix, bonsai, etc.
# IMPORTANT: The command must handle terminal input or exit on 'q'/Ctrl-C 
# to trigger the authentication menu.
VISUAL_ENGINE="tmatrix"

# Arguments for the visual engine.
# For tmatrix: 
#   -s: speed (1-60)
#   -C: color (green, white, red, etc.)
VISUAL_ENGINE_ARGS="-s 60 -C green"

# --- INTERNAL PATHS ---
# Usually these do not need modification once installed.
LOCK_LAUNCHER_SCRIPT="$INSTALL_DIR/lock_screen.sh"
LOCK_UI_SCRIPT="$INSTALL_DIR/lock_ui.sh"
HOWDY_WRAPPER_SCRIPT="$INSTALL_DIR/howdy_wrapper.sh"
SCREEN_WATCHER_SCRIPT="$INSTALL_DIR/screen_watcher.sh"
CAFFEINE_SCRIPT="$INSTALL_DIR/caffeine.sh"
CONFIG_FILE="$INSTALL_DIR/config.sh"
EOF_CONFIG
