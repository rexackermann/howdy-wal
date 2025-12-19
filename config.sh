#!/bin/bash
###############################################################################
#             Howdy-WAL - Central Configuration File                     #
# --------------------------------------------------------------------------- #
# This file contains all the tunable variables for the howdy-WAL system.       #
# Changes here will be reflected across all components.                       #
###############################################################################

# --- INSTALLATION SETTINGS ---
# The path where the project is installed. 
# For system-wide use, this is typically /opt/howdy-WAL
INSTALL_DIR="/opt/howdy-WAL"

# --- LOCKING MECHANISM ---
# If true, uses standard GNOME lock screen. 
# If false, uses the V1 TTY-switching mechanism.
NATIVE_LOCK=true

# --- TIMING & BEHAVIOR ---
# Idle time in milliseconds before triggering the lock (10000 = 10s)
IDLE_THRESHOLD_MS=10000

# SMART MEDIA: If true, will not lock if video/media is in the foreground.
# Uses a heuristic: Audio playing + Active Idle Inhibitor = Foreground Media.
SMART_MEDIA=true

# MATCH MEDIA INHIBITOR: If true, will only skip lock if the application
# playing audio is the SAME as the application inhibiting idle.
# This allows background music (like Spotify) to follow idle policy
# while foreground video (like YouTube) skips it.
MATCH_MEDIA_INHIBITOR=true

# IGNORE INHIBITORS: List of app IDs whose inhibitors should be ignored
# for media detection (e.g. general purpose caffeine extensions).
# Note: They won't stop the lock unless MATCH_MEDIA_INHIBITOR is false.
# Leave empty to allow any inhibitor to match.
IGNORE_INHIBITORS="caffeine-gnome-extension"

# IGNORE PHANTOM AUDIO: Some apps keep audio streams open while paused.
# If true, only RUNNING audio streams prevent locking.
ONLY_RUNNING_AUDIO=true

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

# --- DATA EXPORTERS ---
# The path where the GNOME Extension exports focused window data.
FOCUS_DATA_FILE="/tmp/gnome-audio-status.json"

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
LOG_FILE="/var/log/howdy-wal.log"
LOG_MAX_LINES=1000
VERBOSE=true

# Helper to truncate logs (keep last N lines)
# Run at start of scripts to keep log size manageable
cleanup_logs() {
    if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt "$LOG_MAX_LINES" ]; then
        # Use a temp file to safely truncate
        local tmp_log=$(mktemp)
        tail -n "$LOG_MAX_LINES" "$LOG_FILE" > "$tmp_log"
        cat "$tmp_log" > "$LOG_FILE"
        rm "$tmp_log"
    fi
}

# Communication file to bypass unreliable TTY exit codes
AUTH_SUCCESS_FILE="/tmp/howdy_auth_success"

LOCK_LAUNCHER_SCRIPT="$INSTALL_DIR/lock_screen.sh"
LOCK_UI_SCRIPT="$INSTALL_DIR/lock_ui.sh"
HOWDY_WRAPPER_SCRIPT="$INSTALL_DIR/howdy_wrapper.sh"
SCREEN_WATCHER_SCRIPT="$INSTALL_DIR/screen_watcher.sh"
MEDIA_CHECK_SCRIPT="$INSTALL_DIR/media_check.sh"
CAFFEINE_SCRIPT="$INSTALL_DIR/caffeine.sh"
BLUETOOTH_RECONNECT_SCRIPT="$INSTALL_DIR/bluetooth_reconnect.sh"
CONFIG_FILE="$INSTALL_DIR/config.sh"

