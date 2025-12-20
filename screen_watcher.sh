#!/bin/bash
###############################################################################
#             Howdy-WAL - System Idle Monitor Daemon                     #
# --------------------------------------------------------------------------- #
# This background service watches for system idleness and triggers the        #
# biometric verification or the lock screen as necessary.                     #
###############################################################################

# Determine script location and load central configuration
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
  source "$SCRIPT_DIR/config.sh"
else
  echo "CRITICAL ERROR: config.sh not found in $SCRIPT_DIR"
  exit 1
fi

# --- IDLE DETECTION LOGIC ---
# Intererrogates GNOME's Mutter IdleMonitor via D-Bus.
get_idle_time() {
  gdbus call --session \
    --dest org.gnome.Mutter.IdleMonitor \
    --object-path /org/gnome/Mutter/IdleMonitor/Core \
    --method org.gnome.Mutter.IdleMonitor.GetIdletime 2>/dev/null |
    awk -F' ' '{print $2}' | tr -cd '0-9'
}

is_native_lock_active() {
  local status
  # status=$(gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.GetActive 2>/dev/null)
  status=$(gdbus call --system --dest org.freedesktop.login1 \
    --object-path /org/freedesktop/login1/session/auto \
    --method org.freedesktop.DBus.Properties.Get \
    "org.freedesktop.login1.Session" "LockedHint")
  if [[ "$status" == "(true,)" ]]; then
    echo $status >/tmp/native-lock
    return 0
  fi
  return 1
  echo $status >/tmp/native-lock
}

# --- LOGGING HELPER ---
log_event() {
  local level="$1"
  local message="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # Ensure log file exists and is writable (best effort)
  [ -f "$LOG_FILE" ] || touch "$LOG_FILE" 2>/dev/null
  chmod 666 "$LOG_FILE" 2>/dev/null

  echo "[$timestamp] [$level] $message" >>"$LOG_FILE" 2>/dev/null
  echo -e "[$timestamp] [$level] $message"
}

# Perform initial log cleanup
cleanup_logs

log_event "INFO" "Howdy-WAL Monitor starting up..."

# --- MAIN MONITORING LOOP ---
while true; do
  # 1. Caffeine Check
  if [ -f "$CAFFEINE_FILE" ]; then
    sleep 10
    continue
  fi

  # 2. Native ScreenShield Check (SHIELD-AWARENESS)
  # If the OS is already locked, the monitor should stay dormant
  # to release camera resources for GDM/Howdy-Unlock.
  if is_native_lock_active; then
    sleep 10
    continue
  fi

  # 3. Smart Media Logic
  if "$MEDIA_CHECK_SCRIPT"; then
    sleep 5
    continue
  fi

  # 3. Get current system idle time (milliseconds)
  IDLE_MS=$(get_idle_time)

  if [ -z "$IDLE_MS" ]; then
    sleep 5
    continue
  fi

  # 4. Decision Logic
  if [ "$IDLE_MS" -gt "$IDLE_THRESHOLD_MS" ]; then
    UI_SCRIPT_NAME=$(basename "$LOCK_UI_SCRIPT")

    # Check if lock is currently active
    if ! pgrep -f "$UI_SCRIPT_NAME" >/dev/null && ! pgrep -f "lock_screen.sh" >/dev/null; then
      log_event "TRIGGER" "Idle threshold reached ($IDLE_MS ms). Checking presence..."

      # Step 1: Quick verification
      if ! "$HOWDY_WRAPPER_SCRIPT"; then
        log_event "LOCK" "User not detected. Initiating LOCKdown."

        # Step 2: Full Lock Screen
        "$LOCK_LAUNCHER_SCRIPT"

        log_event "RESUME" "Session resumed. Entering grace period (${UNLOCK_GRACE_PERIOD}s)."
        sleep "$UNLOCK_GRACE_PERIOD"
      else
        log_event "INFO" "User is present. Skipping lock."
        sleep 5
      fi
    fi
  fi

  sleep 1
done
