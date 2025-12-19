# 🛡️ Howdy-WAL

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)

A hardened, terminal-based biometric lockscreen for GNOME/Wayland. This project replaces the standard desktop lockscreen with a high-performance terminal visual engine (like `tmatrix`) running on a dedicated Virtual Terminal (TTY), secured by `howdy` facial recognition.

> [!IMPORTANT]
> This project is designed for **Fedora/GNOME/Wayland** but can be adapted for other distributions. It leverages TTY switching to bypass GUI-level escapes like `Alt-Tab` or `Super` keys.

---

## ✨ Features

- **🚀 Biometric Security**: Seamless unlocking via `howdy` facial recognition.
- **🔒 Hardened TTY Locking**: Switches session to TTY 9, rendering standard desktop bypasses useless.
- **🛡️ Fail-Closed Design**: If the lock UI crashes or is killed, it automatically respawns. Access to the desktop is only granted upon successful authentication.
- **📟 Interchangeable Visuals**: Use `tmatrix`, `cmatrix`, `bonsai`, or any CLI tool as your screensaver.
- **☕ Caffeine Mode**: Quickly pause auto-locking for movie nights or presentations.
- **⌨️ Interactive Fallback**: Secure password entry via PAM if face verification fails.
- **🛠️ System-wide Install**: Deploy to `/opt/howdy-WAL` for clean system integration.

---

## ⚠️ Caution & Warnings

> [!CAUTION]
> **USE AT YOUR OWN RISK**: This project uses a "Sticky TTY" enforcement loop. If you switch away from the lock screen, it will pull you back within 0.5s.
> 
> **For Recovery**: Use your **Emergency VT** (default: `Ctrl+Alt+F3`) to log in and kill the processes if you get stuck. Access to this specific TTY is allowed by the enforcement monitor for debugging.

> [!WARNING]
> **SUDOERS RISK**: The installer creates a `NOPASSWD` rule for the lock launcher. This is necessary to allow the background monitor to secure your system while you are away. Ensure your project directory permissions remain restricted to `root`.

---

## 🛠️ Installation

### 1. Prerequisites & Howdy Setup
This project depends on **Howdy**, which is not available in most official distribution repositories. You must install and configure it manually first.

> [!IMPORTANT]
> **HOWDY INSTALLATION**:
> - **Official Repository**: [boltgolt/howdy](https://github.com/boltgolt/howdy)
> - **Fedora (COPR)**: Most users on Fedora use the `principis/howdy` COPR:
>   ```bash
>   sudo dnf copr enable principis/howdy
>   sudo dnf install howdy pamtester tmatrix
>   ```
> - **Verification**: Ensure `sudo howdy test` works before proceeding with this installer.

### 2. Guided Install
Clone the repository and run the installer:
```bash
git clone https://github.com/rexackermann/howdy-WAL.git
cd howdy-WAL
./install.sh
```
The installer will deploy to `/opt/howdy-WAL`, set up PAM services, configure sudoers, and enable the systemd user daemon.

---

## ⚙️ Configuration

All settings are centralized in `/opt/howdy-WAL/config.sh`. 

| Variable | Description | Default |
| :--- | :--- | :--- |
| `IDLE_THRESHOLD_MS` | Inactivity before locking | `10000` (10s) |
| `VISUAL_ENGINE` | Command for screensaver | `tmatrix` |
| `LOCK_VT` | TTY used for the lock | `9` |
| `MENU_TIMEOUT` | Menu wait time | `10`s |

### Swapping Visuals
To use `cmatrix` instead of `tmatrix`:
1. Open `/opt/howdy-WAL/config.sh`.
2. Change `VISUAL_ENGINE="cmatrix"`.
3. Change `VISUAL_ENGINE_ARGS="-s -C blue"`.

---

## 🖱️ Usage

### Manual Lock
```bash
/opt/howdy-WAL/lock_screen.sh
```

### Caffeine Toggle
Prevent auto-locking temporarily:
```bash
/opt/howdy-WAL/caffeine.sh
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
cd /opt/howdy-WAL
sudo ./uninstall.sh
```

---

## 📄 License
Distributed under the **MIT License**. See [LICENSE](./LICENSE) for more information.

**Author:** Rex Ackermann
