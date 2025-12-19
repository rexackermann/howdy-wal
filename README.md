# 🛡️ Howdy-WAL
### Hardened Terminal-Based Biometric Lockscreen for Linux

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![Security: Hardened](https://img.shields.io/badge/Security-Hardened-red.svg)](#features)

Howdy-WAL (Wait-And-Lock) is a high-performance terminal visual engine lockscreen secured by `howdy` facial recognition. By switching the session to a dedicated Virtual Terminal (TTY), it bypasses all GUI-level escapes (like `Alt+Tab`, `Super`, or notification snooping), providing a truly hardened session lock.

---

## ✨ Features

- **🎧 BT Preservation**: Persistent Bluetooth connections via WirePlumber policy and automatic reconnection helper.
- **👆 Universal Input Wake**: Instant wake on **mouse movement**, **clicks**, **touchpad swipes**, **touchscreen taps**, or any **key press**.
- **🚀 Biometric Security**: Seamless unlocking via `howdy` facial recognition mapping.
- **🔒 Hardened TTY Locking**: Switches to TTY 9, rendering desktop-level bypasses useless.
- **🛡️ Fail-Closed Design**: Automatic respawn on crash. Access is only possible via valid authentication.
- **🎬 Smart Media Detection**: Blocks auto-locking for foreground video (YouTube/Movies) while allowing it for background audio (Spotify).
- **📟 Interchangeable Visuals**: Support for `tmatrix`, `cmatrix`, `bonsai`, or any CLI screensaver.
- **☕ Caffeine Mode**: Quickly pause auto-locking for presentations or "stay awake" sessions.
- **⌨️ Interactive Fallback**: Secure password entry via terminal-safe PAM verification.
- **📜 Audit Logging**: Persistent event tracking at `/var/log/howdy-wal.log`.

---

## ⚠️ Safety First

> [!CAUTION]
> **TTY ENFORCEMENT**: This project uses a "Sticky TTY" loop. If you switch away from the lock screen without authenticating, it will pull you back within 0.5s.
> 
> **EMERGENCY RECOVERY**: If you get stuck, switch to your **Emergency VT** (default: `Ctrl+Alt+F3`). Access to this specific TTY is permitted for debugging and recovery.

---

## 🛠️ Installation

### 1. Prerequisites
Ensure `howdy` and `pamtester` are installed and configured on your system.
For Fedora users:
```bash
sudo dnf copr enable principis/howdy
sudo dnf install howdy pamtester tmatrix
```

### 2. Guided Setup
```bash
git clone https://github.com/USER/howdy-WAL.git
cd howdy-WAL
./install.sh
```

---

## ⚙️ Configuration

Tunable settings are centralized in `/opt/howdy-WAL/config.sh`.

| Variable | Description | Default |
| :--- | :--- | :--- |
| `IDLE_THRESHOLD_MS` | Inactivity (ms) before lock | `10000` (10s) |
| `SMART_MEDIA` | Don't lock during video | `true` |
| `VISUAL_ENGINE` | Visual engine command | `tmatrix` |
| `LOCK_VT` | Virtual Terminal index | `9` |
| `EMERGENCY_VT` | VT for debugging | `3` |

---

## 🖱️ Usage

### Quick Commands
- **Lock Now**: `/opt/howdy-WAL/lock_now.sh` (Rig this to a keyboard shortcut!)
- **Toggle Caffeine**: `/opt/howdy-WAL/caffeine.sh`
- **View Logs**: `tail -f /var/log/howdy-wal.log`

### Unlock Flow
- **Interaction**: Move the mouse, swipe the touchpad, or press any key to stop the screensaver and trigger the camera.
- **Biometric Fail**: An interactive menu will appear allowing **[P]assword** or **[R]etry**.

---

## 🗑️ Uninstallation
Remove all hooks and files:
```bash
sudo /opt/howdy-WAL/uninstall.sh
```

---

## 📄 License
Distributed under the **MIT License**. Created by the Howdy-WAL Contributors.
