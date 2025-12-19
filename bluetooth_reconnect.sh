#!/bin/bash
###############################################################################
#             Howdy-WAL - Bluetooth Reconnect Helper                        #
# --------------------------------------------------------------------------- #
# Captures connected devices and attempts to restore them after unlock.       #
###############################################################################

STATE_FILE="/tmp/howdy_bluetooth_state"

save_state() {
    # Extract MAC addresses of currently connected devices
    bluetoothctl devices Connected | awk '{print $2}' > "$STATE_FILE"
}

restore_state() {
    if [ -f "$STATE_FILE" ]; then
        while read -r mac; do
            if [ -n "$mac" ]; then
                echo "Attempting to reconnect Bluetooth device: $mac"
                bluetoothctl connect "$mac" >/dev/null 2>&1 &
            fi
        done < "$STATE_FILE"
        rm -f "$STATE_FILE"
    fi
}

case "$1" in
    save)
        save_state
        ;;
    restore)
        restore_state
        ;;
    *)
        echo "Usage: $0 {save|restore}"
        exit 1
        ;;
esac
