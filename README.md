# 🛡️ Howdy-WAL
### Hardened Session-Native Biometric Lockscreen for Linux

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![Security: Hardened](https://img.shields.io/badge/Security-Hardened-red.svg)](#features)

Howdy-WAL is a high-performance biometric lockscreen secured by Howdy facial recognition. Unlike traditional lockscreens that switch TTYs, Howdy-WAL stays within your graphical session using a **Hardened Shell Overlay**, ensuring that Bluetooth audio, background media, and session state are never interrupted.

---

## ✨ Features

- **🚀 Session-Native**: Zero Bluetooth disconnects or TTY switch delays. Audio stays 100% persistent.
- **🛡️ Hardened Overlay**: A native GNOME Shell Extension draws a modal shield and grabs all input.
- **👆 Universal Wake**: Instant wake on **mouse movement**, **clicks**, **touchpad swipes**, or any **key press**.
- **🚀 Biometric Security**: Seamless unlocking via `howdy` facial recognition mapping.
- **🎬 Smart Media Recognition**: Optionally blocks auto-locking for foreground video while allowing it for background audio.
- **⌨️ Secure Fallback**: Matrix-styled native password entry box for when biometrics are unavailable.
- **🆘 Emergency Bypass**: Rapid triple-press of the `Escape` key provides a fail-safe session recovery.

---

## 🛠️ Installation

### 1. Prerequisites
Ensure `howdy` and `python3-pam` are installed.
For Fedora users:
```bash
sudo dnf copr enable principis/howdy
sudo dnf install howdy python3-pam zip gdbus
```

### 2. Guided Setup
```bash
git clone https://github.com/rexackermann/howdy-wal.git
cd howdy-wal
./install.sh
```
> [!IMPORTANT]
> Because this uses a GNOME Shell Extension, you MUST **Log Out and Log Back In** after installation for the changes to take effect.

---

## 🖱️ Usage

### Quick Commands
- **Lock Now**: `/opt/howdy-WAL/lock.sh` (Bind this to a keyboard shortcut!)
- **View Logs**: `tail -f /var/log/howdy-wal.log`

### Unlock Flow
- **Interaction**: Move the mouse, swipe the touchpad, or press any key to trigger the camera.
- **Emergency Abort**: Press `Escape` 3 times rapidly if you need to bypass the lock manually.

---

## 📄 License
Distributed under the **MIT License**. Created by the Howdy-WAL Contributors.

---

## 📦 Legacy Versions
The original TTY-based implementation is preserved in the `version1/` directory for historical reference.
