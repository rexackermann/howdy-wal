# 🛡️ Howdy Autolock

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)

A hardened, terminal-based biometric lockscreen for GNOME/Wayland. This project replaces the standard desktop lockscreen with a high-performance terminal visual engine (like `tmatrix`) running on a dedicated Virtual Terminal (TTY), secured by `howdy` facial recognition.

> [!IMPORTANT]
> This project is designed for **Fedora/GNOME/Wayland** but can be adapted for other distributions. It leverages TTY switching to bypass GUI-level escapes like `Alt-Tab` or `Super` keys.

---

## ✨ Features

- **🚀 Biometric Security**: Seamless unlocking via `howdy` facial recognition.
- **🔒 Hardened TTY Locking**: Switches session to TTY 9, rendering standard desktop bypasses useless.
- **📟 Interchangeable Visuals**: Use `tmatrix`, `cmatrix`, `bonsai`, or any CLI tool as your screensaver.
- **☕ Caffeine Mode**: Quickly pause auto-locking for movie nights or presentations.
- **⌨️ Interactive Fallback**: Secure password entry via PAM if face verification fails.
- **🛠️ System-wide Install**: Deploy to `/opt/howdy-autolock` for clean system integration.

---

## ⚠️ Caution & Warnings

> [!CAUTION]
> **USE AT YOUR OWN RISK**: This script switches Virtual Terminals. While stable, if the `lock_ui.sh` script crashes or is terminated improperly, you might be stuck on a text console.
> Keep a secondary TTY (`Ctrl+Alt+F3`) or SSH access available during your first test.

> [!WARNING]
> **SUDOERS RISK**: The installer creates a `NOPASSWD` rule for the lock launcher. This is necessary to allow the background monitor to secure your system while you are away. Ensure your project directory permissions remain restricted to `root`.

---

## 🛠️ Installation

### 1. Prerequisites
Ensure you have the following packages installed:
```bash
sudo dnf install howdy pamtester tmatrix
```
*Note: `tmatrix` can be replaced in `config.sh`.*

### 2. Guided Install
Clone the repository and run the installer:
```bash
git clone https://github.com/rexackermann/howdy-autolock.git
cd howdy-autolock
./install.sh
```
The installer will deploy to `/opt/howdy-autolock`, set up PAM services, configure sudoers, and enable the systemd user daemon.

---

## ⚙️ Configuration

All settings are centralized in `/opt/howdy-autolock/config.sh`. 

| Variable | Description | Default |
| :--- | :--- | :--- |
| `IDLE_THRESHOLD_MS` | Inactivity before locking | `10000` (10s) |
| `VISUAL_ENGINE` | Command for screensaver | `tmatrix` |
| `LOCK_VT` | TTY used for the lock | `9` |
| `MENU_TIMEOUT` | Menu wait time | `10`s |

### Swapping Visuals
To use `cmatrix` instead of `tmatrix`:
1. Open `/opt/howdy-autolock/config.sh`.
2. Change `VISUAL_ENGINE="cmatrix"`.
3. Change `VISUAL_ENGINE_ARGS="-s -C blue"`.

---

## 🖱️ Usage

### Manual Lock
```bash
/opt/howdy-autolock/lock_screen.sh
```

### Caffeine Toggle
Prevent auto-locking temporarily:
```bash
/opt/howdy-autolock/caffeine.sh
```

### Interactive Menu
While locked, press **`Q`** to trigger verification. If it fails:
- Press **`R`** to retry face scan.
- Press **`P`** to enter your system password.
- Wait **10s** to return to the screensaver.

---

## 🗑️ Uninstallation

To completely remove the project and all system hooks:
```bash
cd /opt/howdy-autolock
sudo ./uninstall.sh
```

---

## 📄 License
Distributed under the **MIT License**. See `LICENSE` for more information.

**Author:** Rex Ackermann
