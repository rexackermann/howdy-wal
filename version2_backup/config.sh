#!/bin/bash
###############################################################################
#             Howdy-WAL V2 - Central Configuration File                      #
# --------------------------------------------------------------------------- #
# This file contains all the tunable variables for the howdy-WAL system.       #
###############################################################################

# --- INSTALLATION SETTINGS ---
INSTALL_DIR="/opt/howdy-WAL"
TARGET_USER="rex"

# --- TIMING & BEHAVIOR ---
# Idle time in milliseconds before triggering the lock (10000 = 10s)
IDLE_THRESHOLD_MS=10000

# SMART MEDIA: If true, will not lock if video/media is in the foreground.
SMART_MEDIA=true

# MATCH MEDIA INHIBITOR: If true, will only skip lock if the application
# playing audio is the SAME as the application inhibiting idle.
MATCH_MEDIA_INHIBITOR=true

# IGNORE INHIBITORS: List of app IDs whose inhibitors should be ignored.
IGNORE_INHIBITORS="caffeine-gnome-extension"

# IGNORE PHANTOM AUDIO: Some apps keep audio streams open while paused.
ONLY_RUNNING_AUDIO=true

# Grace period (seconds) after unlocking before the monitor resumes checking.
UNLOCK_GRACE_PERIOD=30

# --- AUTHENTICATION SERVICES ---
# The PAM service used for face verification.
PAM_SERVICE="faceauth"

# THE PAM service used for password fallback.
SUDO_SERVICE="sudo"

# --- DATA EXPORTERS ---
# The path where the GNOME Extension exports focused window data.
FOCUS_DATA_FILE="/tmp/gnome-audio-status.json"

# --- CAFFEINE MODE ---
CAFFEINE_FILE="/tmp/howdy_caffeine"

# --- INTERNAL PATHS ---
LOG_FILE="/var/log/howdy-wal.log"
LOG_MAX_LINES=1000
VERBOSE=true

# Helper to truncate logs.
cleanup_logs() {
    if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt "$LOG_MAX_LINES" ]; then
        local tmp_log=$(mktemp)
        tail -n "$LOG_MAX_LINES" "$LOG_FILE" > "$tmp_log"
        cat "$tmp_log" > "$LOG_FILE"
        rm "$tmp_log"
    fi
}

# Script Paths
HOWDY_WRAPPER_SCRIPT="$INSTALL_DIR/howdy_wrapper.sh"
CONFIG_FILE="$INSTALL_DIR/config.sh"
PAM_VERIFY_SCRIPT="$INSTALL_DIR/pam_verify.py"
LOCK_SCRIPT="$INSTALL_DIR/lock.sh"
MONITOR_SCRIPT="$INSTALL_DIR/monitor.sh"
MEDIA_CHECK_SCRIPT="$INSTALL_DIR/media_check.sh"
CAFFEINE_SCRIPT="$INSTALL_DIR/caffeine.sh"
