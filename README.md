# Howdy-WAL (Native Stability Edition) 🐺🚀

**Howdy-WAL** is a "Smart" Walk-Away Lock system for GNOME that uses facial recognition (Howdy) and presence detection to keep your session secure without interfering with your work.

## 🌟 Why the Native Edition?
Early V2 versions used a custom Shell extension for locking. We have pivoted to a **Native Hybrid Architecture** to provide the absolute maximum stability.
- **🛡️ Rock Solid**: Uses the standard GNOME lock screen (no "black box" extension bugs).
- **🧠 The Brain**: A background monitor handles the "Smart" logic (Media detection, Caffeine).
- **📸 Biometric Speed**: Proactively checks for your face *before* locking to prevent interruptions.
- **🎵 Persistent Media/BT**: Keeps your Bluetooth and Audio alive by staying on the same session.

## ✨ Core Features
- **Smart Idle Detection**: Blocks locking if media (video/audio) is in the foreground.
- **Howdy Integration**: Bio-bypass checks for your face before triggering the lock.
- **Caffeine Mode**: Toggle a temporary "never-lock" state with a simple script.
- **GDM Integration**: (Optional) Makes the native GNOME lock screen use Howdy instantly.

## 🚀 Installation
1.  **Run the Installer**:
    ```bash
    ./install.sh
    ```
2.  **Enable the Support Extension**:
    - Enable **"Focus Exporter"** in your GNOME Extension Manager.
3.  **Active Biometrics (Recommended)**:
    - This allows the standard GNOME lock screen to use Howdy:
    ```bash
    sudo /opt/howdy-WAL/integrate_pam.sh
    ```
4.  **Start the Daemon**:
    ```bash
    systemctl --user start howdy-WAL.service
    ```

## 🛠️ Essential Commands
- **Lock Now**: `/opt/howdy-WAL/lock_now.sh`
- **Toggle Caffeine**: `/opt/howdy-WAL/caffeine.sh`
- **Check Logs**: `tail -f /var/log/howdy-wal.log`

---
*Created by Howdy-WAL Contributors. Licensed under MIT.*
